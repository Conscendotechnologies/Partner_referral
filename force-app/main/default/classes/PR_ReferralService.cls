/**
 * 002 Partner referral (S02): server-side validation and submission of a referral from the partner portal.
 * Every form rule is re-checked here; agent, agency, consent and Lead Source are stamped and can never come
 * from the client.
 */
public with sharing class PR_ReferralService {
    private static final Pattern MOBILE_PATTERN = Pattern.compile('^(04\\d{8}|\\+614\\d{8})$');
    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
    private static final Pattern POSTCODE_PATTERN = Pattern.compile('^\\d{4}$');

    /** Lead.FirstName and Lead.City are 40 characters; longer values would fail the Lead insert. */
    public static final Integer FIRST_NAME_MAX = 40;
    public static final Integer SUBURB_MAX = 40;

    public static String normaliseMobile(String mobile) {
        return mobile == null ? null : mobile.replaceAll('[\\s\\-()]', '');
    }

    /** One stored format for both accepted inputs: +614XXXXXXXX becomes 04XXXXXXXX. */
    public static String canonicalMobile(String mobile) {
        String m = normaliseMobile(mobile);
        if (m != null && m.startsWith('+614')) {
            m = '0' + m.substring(3);
        }
        return m;
    }

    /** Both spellings of a canonical mobile, so records stored before canonicalisation still match. */
    public static List<String> mobileVariants(String canonical) {
        if (String.isBlank(canonical) || !canonical.startsWith('04')) {
            return new List<String>{ canonical };
        }
        return new List<String>{ canonical, '+61' + canonical.substring(1) };
    }

    /** Returns every rule the input breaks (empty list = valid). */
    public static List<String> validate(PR_ReferralInput i) {
        List<String> errors = new List<String>();
        if (i == null) {
            return new List<String>{ 'Referral details are missing.' };
        }
        if (String.isBlank(i.firstName)) {
            errors.add('First name is required.');
        } else if (i.firstName.trim().length() > FIRST_NAME_MAX) {
            errors.add('First name must be ' + FIRST_NAME_MAX + ' characters or fewer.');
        }
        if (String.isBlank(i.lastName)) errors.add('Last name is required.');
        String mobile = normaliseMobile(i.mobile);
        if (String.isBlank(mobile) || !MOBILE_PATTERN.matcher(mobile).matches()) {
            errors.add('Mobile must be an Australian mobile: 04 and 8 digits, or +614 and 8 digits.');
        }
        if (String.isNotBlank(i.email) && !EMAIL_PATTERN.matcher(i.email.trim()).matches()) {
            errors.add('Email is not valid.');
        }
        if (String.isBlank(i.street)) errors.add('Street is required.');
        if (String.isBlank(i.suburb)) {
            errors.add('Suburb is required.');
        } else if (i.suburb.trim().length() > SUBURB_MAX) {
            errors.add('Suburb must be ' + SUBURB_MAX + ' characters or fewer.');
        }
        if (String.isBlank(i.state) || !PR_Settings.STATES.contains(i.state)) errors.add('State is required.');
        if (String.isBlank(i.postcode) || !POSTCODE_PATTERN.matcher(i.postcode.trim()).matches()) {
            errors.add('Postcode must be 4 digits.');
        }
        if (i.moveInDate == null) {
            errors.add('Move-in date is required.');
        } else if (i.moveInDate < Date.today().addDays(-7) || i.moveInDate > Date.today().addMonths(6)) {
            errors.add('Move-in date must be between 7 days ago and 6 months from today.');
        }
        Set<String> picked = new Set<String>();
        if (i.utilities != null) {
            for (String u : i.utilities) {
                if (PR_Settings.UTILITIES.contains(u)) picked.add(u);
            }
        }
        if (picked.isEmpty()) errors.add('Choose at least one service.');
        if (i.consent != true) errors.add('The customer must give consent.');
        return errors;
    }

    public static PR_SubmitResult submit(PR_ReferralInput i) {
        return submitAll(new List<PR_ReferralInput>{ i })[0];
    }

    /**
     * AC-02.12: bulk-safe submission. One context lookup, one duplicate query, one Referral insert and one Lead
     * insert however many referrals are sent. A referral with a same-agency duplicate that was not acknowledged is
     * returned with duplicateWarning and not saved; the others are saved.
     */
    public static List<PR_SubmitResult> submitAll(List<PR_ReferralInput> inputs) {
        PR_SystemData.PortalContext ctx = PR_SystemData.currentContext();
        if (ctx.contactId == null || ctx.accountId == null) {
            throw new PR_Exception('Only partner agents can submit referrals.');
        }
        if (ctx.agencyStatus != PR_Settings.AGENCY_ACTIVE) {
            throw new PR_Exception('Your agency is not active, so new referrals cannot be submitted. Contact your Connectnow Partner Manager.');
        }
        if (!Schema.SObjectType.Referral__c.isCreateable()) {
            throw new PR_Exception('You do not have access to submit referrals.');
        }
        for (Integer n = 0; n < inputs.size(); n++) {
            List<String> errors = validate(inputs[n]);
            if (!errors.isEmpty()) {
                throw new PR_Exception((inputs.size() > 1 ? 'Referral ' + (n + 1) + ': ' : '') + String.join(errors, ' '));
            }
        }

        // AC-02.8 / AC-02.9: one query for every open referral sharing a mobile with any input.
        Set<String> variants = new Set<String>();
        for (PR_ReferralInput i : inputs) variants.addAll(mobileVariants(canonicalMobile(i.mobile)));
        List<Referral__c> open = PR_SystemData.openReferralsForMobiles(variants);
        // Group candidates by canonical mobile once, so each input is compared only with referrals for the same mobile.
        Map<String, List<Referral__c>> openByMobile = byMobile(open);
        Map<String, List<Referral__c>> acceptedByMobile = new Map<String, List<Referral__c>>();

        Partner_Referral_Setting__mdt s = PR_Settings.get();
        List<PR_SubmitResult> results = new List<PR_SubmitResult>();
        List<Referral__c> toCreate = new List<Referral__c>();
        List<PR_SubmitResult> createdResults = new List<PR_SubmitResult>();
        Set<Id> otherAgencyMatches = new Set<Id>();
        for (PR_ReferralInput i : inputs) {
            String mobile = canonicalMobile(i.mobile);
            String email = String.isBlank(i.email) ? null : i.email.trim().toLowerCase();
            PR_SubmitResult result = new PR_SubmitResult();
            results.add(result);
            Set<Id> others = new Set<Id>();
            for (Referral__c r : candidates(openByMobile, mobile)) {
                if (!isSameMover(r, mobile, email)) continue;
                if (r.Referring_Agency__c == ctx.accountId) {
                    result.duplicates.add(r.Name + ' (' + r.First_Name__c + ' ' + r.Last_Name__c + ')');
                } else {
                    others.add(r.Id);
                }
            }
            // Earlier inputs accepted in this same call are not in the database yet; they come from this agency, so a
            // match is a same-agency duplicate and needs the same acknowledgement.
            for (Referral__c accepted : candidates(acceptedByMobile, mobile)) {
                if (isSameMover(accepted, mobile, email)) {
                    result.duplicates.add('earlier in this submission (' + accepted.First_Name__c + ' ' + accepted.Last_Name__c + ')');
                }
            }
            if (!result.duplicates.isEmpty() && i.acknowledgeDuplicate != true) {
                result.duplicateWarning = true;
                continue;
            }
            Set<String> picked = new Set<String>(i.utilities);
            List<String> utilities = new List<String>();
            for (String u : PR_Settings.UTILITIES) {
                if (picked.contains(u)) utilities.add(u);
            }
            Referral__c r = new Referral__c(
                OwnerId = UserInfo.getUserId(),
                First_Name__c = i.firstName.trim(),
                Last_Name__c = i.lastName.trim(),
                Mobile__c = mobile,
                Email__c = email,
                New_Street__c = i.street.trim(),
                New_Suburb__c = i.suburb.trim(),
                New_State__c = i.state,
                New_Postcode__c = i.postcode.trim(),
                Previous_Address__c = i.previousAddress,
                Move_In_Date__c = i.moveInDate,
                Utilities__c = String.join(utilities, ';'),
                Agent_Notes__c = i.notes,
                Referring_Agent__c = ctx.contactId,
                Referring_Agency__c = ctx.accountId,
                Consent_Given__c = true,
                Consent_Given_At__c = System.now(),
                Consent_Version__c = s.Consent_Version__c,
                Partner_Status__c = PR_Settings.REF_RECEIVED,
                Is_Urgent__c = PR_Settings.isUrgent(i.moveInDate),
                Possible_Duplicate__c = !others.isEmpty()
            );
            r.put('CurrencyIsoCode', PR_Settings.currencyCode());
            toCreate.add(r);
            candidatesFor(acceptedByMobile, mobile).add(r);
            createdResults.add(result);
            otherAgencyMatches.addAll(others);
        }

        // Only the writes flagging will really make: an already-flagged match costs nothing; an unflagged one costs
        // its Referral, plus its Lead when that Lead is still open (PR_SystemData.flagPossibleDuplicates).
        Map<Id, Referral__c> openById = new Map<Id, Referral__c>(open);
        Integer flagRows = 0;
        for (Id matchId : otherAgencyMatches) {
            Referral__c m = openById.get(matchId);
            if (m == null || m.Possible_Duplicate__c) continue;
            flagRows += 1;
            if (m.Lead__c != null && !m.Lead__r.IsConverted) flagRows += 1;
        }
        requireDmlBudget(createRows(toCreate) + flagRows);
        // One unit of work: if any write fails (for example a matching Lead cannot be flagged), nothing is saved and the
        // agent gets a clear error, instead of new referrals saved next to a match that was only half flagged.
        Savepoint sp = Database.setSavepoint();
        try {
            PR_SystemData.createReferralsAndLeads(toCreate);
            // AC-02.9: a cross-agency match is flagged on both referrals (internal only, never shown to partners).
            PR_SystemData.flagPossibleDuplicates(otherAgencyMatches);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new PR_Exception('The referral could not be saved because a related record could not be updated (' + e.getDmlMessage(0) + '). Nothing was saved. Please try again.');
        }
        Map<Id, String> numbers = PR_SystemData.referralNumbers(new Map<Id, Referral__c>(toCreate).keySet());
        for (Integer n = 0; n < toCreate.size(); n++) {
            createdResults[n].saved = true;
            createdResults[n].referralId = toCreate[n].Id;
            createdResults[n].referralNumber = numbers.get(toCreate[n].Id);
        }
        return results;
    }

    /** DML rows the platform still allows in this transaction; tests can lower it to exercise the guard. */
    @TestVisible
    private static Integer dmlRowsAvailableOverride;

    /**
     * DML rows creating these referrals writes: the Referral insert, the Lead insert and the Referral link update (3).
     * The Lead trigger's status sync writes nothing more when the Lead goes to a queue (status stays Received, no rep
     * name), which is every state with a route. Only when no queue is found does the Lead stay with the submitting
     * user, and the sync then writes the rep's first name on the Referral (a 4th row).
     */
    @TestVisible
    private static Integer createRows(List<Referral__c> refs) {
        Integer rows = 0;
        for (Referral__c r : refs) {
            rows += PR_Settings.routeQueueId(r.New_State__c) != null ? 3 : 4;
        }
        return rows;
    }

    /**
     * Refuses a submission whose writes would exceed what is left of the transaction's DML-row limit (10,000), which
     * would otherwise fail with an uncatchable governor exception part-way through. Checked before any write, so
     * nothing is saved.
     */
    @TestVisible
    private static void requireDmlBudget(Integer needed) {
        Integer available = dmlRowsAvailableOverride != null
            ? dmlRowsAvailableOverride
            : Limits.getLimitDmlRows() - Limits.getDmlRows();
        if (needed > available) {
            throw new PR_Exception(
                'This submission would update too many records at once (' + needed + ' rows, ' + available +
                ' available), usually because many existing referrals share these mobile numbers. ' +
                'Submit fewer referrals at a time.'
            );
        }
    }

    private static Map<String, List<Referral__c>> byMobile(List<Referral__c> refs) {
        Map<String, List<Referral__c>> result = new Map<String, List<Referral__c>>();
        for (Referral__c r : refs) candidatesFor(result, canonicalMobile(r.Mobile__c)).add(r);
        return result;
    }

    private static List<Referral__c> candidatesFor(Map<String, List<Referral__c>> index, String mobile) {
        if (!index.containsKey(mobile)) index.put(mobile, new List<Referral__c>());
        return index.get(mobile);
    }

    private static List<Referral__c> candidates(Map<String, List<Referral__c>> index, String mobile) {
        List<Referral__c> found = index.get(mobile);
        return found == null ? new List<Referral__c>() : found;
    }

    /** AC-02.8: same mover = same mobile (either format) and, when both referrals have an email, the same email. */
    private static Boolean isSameMover(Referral__c existing, String mobile, String email) {
        if (canonicalMobile(existing.Mobile__c) != mobile) return false;
        if (String.isBlank(email) || String.isBlank(existing.Email__c)) return true;
        return existing.Email__c.equalsIgnoreCase(email);
    }
}
