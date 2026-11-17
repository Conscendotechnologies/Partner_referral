/**
 * 002 Partner referral: the few reads and writes a partner user needs that their own access must not allow
 * (Leads, other agencies' referrals for duplicate flags). Kept small on purpose; callers decide what to expose.
 */
public without sharing class PR_SystemData {
    public class PortalContext {
        public Id userId;
        public Id contactId;
        public Id accountId;
        public String agencyName;
        public String agencyStatus;
        public Boolean isPrincipal = false;
    }

    public static PortalContext currentContext() {
        PortalContext ctx = new PortalContext();
        ctx.userId = UserInfo.getUserId();
        User u = [
            SELECT ContactId, Contact.AccountId, Contact.Account.Name, Contact.Account.Partner_Status__c, Contact.Portal_Role__c
            FROM User
            WHERE Id = :ctx.userId
        ];
        if (u.ContactId != null) {
            ctx.contactId = u.ContactId;
            ctx.accountId = u.Contact.AccountId;
            ctx.agencyName = u.Contact.Account.Name;
            ctx.agencyStatus = u.Contact.Account.Partner_Status__c;
            ctx.isPrincipal = u.Contact.Portal_Role__c == 'Principal';
        }
        return ctx;
    }

    /**
     * AC-02.8: open referrals (not Connected or Closed Lost) whose mobile is one of the given spellings, from every
     * agency. The caller decides which are the same mover and which agency they belong to.
     */
    public static List<Referral__c> openReferralsForMobiles(Set<String> mobiles) {
        if (mobiles == null || mobiles.isEmpty()) {
            return new List<Referral__c>();
        }
        // Never truncate silently: a missing candidate would let a duplicate through without its warning or flag.
        // Read one more than the cap; if the cap is exceeded, refuse the submission with a clear error instead.
        Integer limitPlusOne = DUPLICATE_CANDIDATE_CAP + 1;
        List<Referral__c> rows = [
            SELECT Id, Name, First_Name__c, Last_Name__c, Mobile__c, Email__c, Referring_Agency__c,
                Possible_Duplicate__c, Lead__c, Lead__r.IsConverted
            FROM Referral__c
            WHERE Mobile__c IN :mobiles
                AND Partner_Status__c NOT IN (:PR_Settings.REF_CONNECTED, :PR_Settings.REF_CLOSED_LOST)
            ORDER BY CreatedDate DESC
            LIMIT :limitPlusOne
        ];
        if (rows.size() > DUPLICATE_CANDIDATE_CAP) {
            throw new PR_Exception(
                'Too many open referrals share these mobile numbers to check for duplicates (more than ' +
                DUPLICATE_CANDIDATE_CAP + '). Submit fewer referrals at a time.'
            );
        }
        return rows;
    }

    /** Most open referrals the duplicate check reads in one submission (well inside the 50,000-row query limit). */
    @TestVisible
    private static Integer DUPLICATE_CANDIDATE_CAP = 10000;

    /** Tests set this to make the Lead flag update fail, to prove the submission then saves nothing. */
    @TestVisible
    private static Boolean failLeadFlagForTest = false;

    /**
     * AC-02.9: marks existing referrals (and their Leads) as possible duplicates of a referral from another agency.
     * All or nothing: if a Lead cannot be flagged, the DmlException propagates and the caller rolls the submission
     * back. A Referral flagged without its Lead would never be retried, because flagged referrals are skipped.
     */
    public static void flagPossibleDuplicates(Set<Id> referralIds) {
        if (referralIds == null || referralIds.isEmpty()) {
            return;
        }
        List<Referral__c> refs = new List<Referral__c>();
        List<Lead> leads = new List<Lead>();
        for (Referral__c r : [SELECT Id, Lead__c, Lead__r.IsConverted FROM Referral__c WHERE Id IN :referralIds AND Possible_Duplicate__c = FALSE]) {
            refs.add(new Referral__c(Id = r.Id, Possible_Duplicate__c = true));
            if (r.Lead__c != null && !r.Lead__r.IsConverted) {
                Lead l = new Lead(Id = r.Lead__c, Possible_Duplicate__c = true);
                if (failLeadFlagForTest) l.LastName = null; // a required field: the update fails
                leads.add(l);
            }
        }
        update refs;
        update leads;
    }

    /** Inserts the referrals, then their Partner Referral Leads (routed by the Lead trigger), and links them. */
    public static void createReferralsAndLeads(List<Referral__c> refs) {
        if (refs.isEmpty()) {
            return;
        }
        insert refs;
        List<Lead> leads = new List<Lead>();
        for (Referral__c r : refs) {
            Lead l = new Lead(
                RecordTypeId = PR_Settings.leadRecordTypeId(),
                OwnerId = PR_Settings.routeQueueId(r.New_State__c),
                Status = PR_Settings.LEAD_NEW,
                LeadSource = PR_Settings.LEAD_SOURCE,
                FirstName = r.First_Name__c,
                LastName = r.Last_Name__c,
                MobilePhone = r.Mobile__c,
                Email = r.Email__c,
                Street = r.New_Street__c,
                City = r.New_Suburb__c,
                State = r.New_State__c,
                PostalCode = r.New_Postcode__c,
                Country = 'Australia',
                Description = r.Agent_Notes__c,
                Referral__c = r.Id,
                Referring_Agency__c = r.Referring_Agency__c,
                Referring_Agent__c = r.Referring_Agent__c,
                Previous_Address__c = r.Previous_Address__c,
                Move_In_Date__c = r.Move_In_Date__c,
                Utilities__c = r.Utilities__c,
                Consent_Given_At__c = r.Consent_Given_At__c,
                Consent_Version__c = r.Consent_Version__c,
                Possible_Duplicate__c = r.Possible_Duplicate__c
            );
            l.put('CurrencyIsoCode', PR_Settings.currencyCode());
            leads.add(l);
        }
        Database.DMLOptions opts = new Database.DMLOptions();
        opts.DuplicateRuleHeader.allowSave = true;
        opts.DuplicateRuleHeader.runAsCurrentUser = false;
        opts.optAllOrNone = true;
        for (Database.SaveResult sr : Database.insert(leads, opts)) {
            if (!sr.isSuccess()) {
                throw new PR_Exception(sr.getErrors()[0].getMessage());
            }
        }
        List<Referral__c> links = new List<Referral__c>();
        for (Integer n = 0; n < refs.size(); n++) {
            refs[n].Lead__c = leads[n].Id;
            links.add(new Referral__c(Id = refs[n].Id, Lead__c = leads[n].Id));
        }
        update links;
    }

    /** Single-referral form, used by the demo data script. */
    public static void createReferralAndLead(Referral__c r) {
        createReferralsAndLeads(new List<Referral__c>{ r });
    }

    public static Map<Id, String> referralNumbers(Set<Id> referralIds) {
        Map<Id, String> out = new Map<Id, String>();
        for (Referral__c r : [SELECT Id, Name FROM Referral__c WHERE Id IN :referralIds]) out.put(r.Id, r.Name);
        return out;
    }
}
