/**
 * 002 Partner referral (S02): server-side validation and submission of a referral from the partner portal.
 * Every form rule is re-checked here; agent, agency, consent and Lead Source are stamped and can never come
 * from the client.
 */
public with sharing class PR_ReferralService {
    public class ReferralInput {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String suburb { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String postcode { get; set; }
        @AuraEnabled public String previousAddress { get; set; }
        @AuraEnabled public Date moveInDate { get; set; }
        @AuraEnabled public List<String> utilities { get; set; }
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public Boolean consent { get; set; }
        @AuraEnabled public Boolean acknowledgeDuplicate { get; set; }
    }

    public class SubmitResult {
        @AuraEnabled public Boolean saved = false;
        @AuraEnabled public Id referralId;
        @AuraEnabled public String referralNumber;
        @AuraEnabled public Boolean duplicateWarning = false;
        @AuraEnabled public List<String> duplicates = new List<String>();
    }

    private static final Pattern MOBILE_PATTERN = Pattern.compile('^(04\\d{8}|\\+614\\d{8})$');
    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
    private static final Pattern POSTCODE_PATTERN = Pattern.compile('^\\d{4}$');

    public static String normaliseMobile(String mobile) {
        return mobile == null ? null : mobile.replaceAll('[\\s\\-()]', '');
    }

    /** Returns every rule the input breaks (empty list = valid). */
    public static List<String> validate(ReferralInput i) {
        List<String> errors = new List<String>();
        if (i == null) {
            return new List<String>{ 'Referral details are missing.' };
        }
        if (String.isBlank(i.firstName)) errors.add('First name is required.');
        if (String.isBlank(i.lastName)) errors.add('Last name is required.');
        String mobile = normaliseMobile(i.mobile);
        if (String.isBlank(mobile) || !MOBILE_PATTERN.matcher(mobile).matches()) {
            errors.add('Mobile must be an Australian mobile: 04 and 8 digits, or +614 and 8 digits.');
        }
        if (String.isNotBlank(i.email) && !EMAIL_PATTERN.matcher(i.email.trim()).matches()) {
            errors.add('Email is not valid.');
        }
        if (String.isBlank(i.street)) errors.add('Street is required.');
        if (String.isBlank(i.suburb)) errors.add('Suburb is required.');
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

    public static SubmitResult submit(ReferralInput i) {
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
        List<String> errors = validate(i);
        if (!errors.isEmpty()) {
            throw new PR_Exception(String.join(errors, ' '));
        }
        String mobile = normaliseMobile(i.mobile);
        String email = String.isBlank(i.email) ? null : i.email.trim().toLowerCase();

        SubmitResult result = new SubmitResult();
        result.duplicates = PR_SystemData.sameAgencyDuplicates(ctx.accountId, mobile, email);
        if (!result.duplicates.isEmpty() && i.acknowledgeDuplicate != true) {
            result.duplicateWarning = true;
            return result;
        }

        Partner_Referral_Setting__mdt s = PR_Settings.get();
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
            Possible_Duplicate__c = PR_SystemData.hasOtherAgencyDuplicate(ctx.accountId, mobile, email)
        );
        r.put('CurrencyIsoCode', PR_Settings.currencyCode());
        PR_SystemData.createReferralAndLead(r);

        result.saved = true;
        result.referralId = r.Id;
        result.referralNumber = PR_SystemData.referralNumber(r.Id);
        return result;
    }
}
