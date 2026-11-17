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

    /** Same agency, same mobile or same email: returns "REF-000123 (Jane Citizen)" labels. */
    public static List<String> sameAgencyDuplicates(Id agencyId, String mobile, String email) {
        List<String> labels = new List<String>();
        for (Referral__c r : findMatches(agencyId, true, mobile, email)) {
            labels.add(r.Name + ' (' + r.First_Name__c + ' ' + r.Last_Name__c + ')');
        }
        return labels;
    }

    /** Cross-agency match: only flagged internally, never shown to partners. */
    public static Boolean hasOtherAgencyDuplicate(Id agencyId, String mobile, String email) {
        return !findMatches(agencyId, false, mobile, email).isEmpty();
    }

    private static List<Referral__c> findMatches(Id agencyId, Boolean sameAgency, String mobile, String email) {
        Date since = Date.today().addDays(-180);
        String soql =
            'SELECT Id, Name, First_Name__c, Last_Name__c FROM Referral__c ' +
            'WHERE CreatedDate >= :since AND Referring_Agency__c ' + (sameAgency ? '=' : '!=') + ' :agencyId ' +
            'AND (Mobile__c = :mobile' + (String.isBlank(email) ? '' : ' OR Email__c = :email') + ') ' +
            'ORDER BY CreatedDate DESC LIMIT 5';
        return Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'since' => since, 'agencyId' => agencyId, 'mobile' => mobile, 'email' => email },
            AccessLevel.SYSTEM_MODE
        );
    }

    /** Inserts the referral, then its Partner Referral Lead routed to the state queue, and links them. */
    public static void createReferralAndLead(Referral__c r) {
        insert r;
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
        Database.DMLOptions opts = new Database.DMLOptions();
        opts.DuplicateRuleHeader.allowSave = true;
        opts.DuplicateRuleHeader.runAsCurrentUser = false;
        Database.SaveResult sr = Database.insert(l, opts);
        if (!sr.isSuccess()) {
            throw new PR_Exception(sr.getErrors()[0].getMessage());
        }
        update new Referral__c(Id = r.Id, Lead__c = l.Id);
        r.Lead__c = l.Id;
    }

    public static String referralNumber(Id referralId) {
        return [SELECT Name FROM Referral__c WHERE Id = :referralId].Name;
    }
}
