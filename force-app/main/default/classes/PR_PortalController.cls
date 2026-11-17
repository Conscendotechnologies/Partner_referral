/**
 * 002 Partner referral (S02, S04): partner portal. Runs with the partner user's sharing, so an agent sees only
 * what they submitted and a principal sees their whole agency (partner role hierarchy). No agency sees another.
 */
public with sharing class PR_PortalController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFormConfig() {
        PR_SystemData.PortalContext ctx = PR_SystemData.currentContext();
        Partner_Referral_Setting__mdt s = PR_Settings.get();
        return new Map<String, Object>{
            'agencyName' => ctx.agencyName,
            'agencyActive' => ctx.agencyStatus == PR_Settings.AGENCY_ACTIVE,
            'isPartner' => ctx.contactId != null,
            'consentText' => s.Consent_Text__c,
            'consentVersion' => s.Consent_Version__c,
            'states' => PR_Settings.STATES,
            'utilities' => PR_Settings.UTILITIES,
            'minMoveIn' => Date.today().addDays(-7),
            'maxMoveIn' => Date.today().addMonths(6)
        };
    }

    @AuraEnabled
    public static PR_SubmitResult submitReferral(PR_ReferralInput input) {
        try {
            return PR_ReferralService.submit(input);
        } catch (Exception e) {
            AuraHandledException a = new AuraHandledException(e.getMessage());
            a.setMessage(e.getMessage());
            throw a;
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<PR_ReferralRow> getReferrals(String statusFilter) {
        String soql =
            'SELECT Id, Name, First_Name__c, Last_Name__c, New_Suburb__c, New_State__c, Move_In_Date__c, Utilities__c, ' +
            'Partner_Status__c, Rep_First_Name__c, Referring_Agent__r.Name, CreatedDate, Is_Urgent__c ' +
            'FROM Referral__c ' + (String.isBlank(statusFilter) ? '' : 'WHERE Partner_Status__c = :statusFilter ') +
            'ORDER BY CreatedDate DESC LIMIT 200';
        List<PR_ReferralRow> rows = new List<PR_ReferralRow>();
        for (Referral__c r : (List<Referral__c>) Database.queryWithBinds(soql, new Map<String, Object>{ 'statusFilter' => statusFilter }, AccessLevel.USER_MODE)) {
            PR_ReferralRow row = new PR_ReferralRow();
            row.id = r.Id;
            row.referralNumber = r.Name;
            row.moverName = r.First_Name__c + ' ' + r.Last_Name__c;
            row.suburb = r.New_Suburb__c + (r.New_State__c == null ? '' : ' ' + r.New_State__c);
            row.moveInDate = r.Move_In_Date__c;
            row.utilities = r.Utilities__c == null ? '' : r.Utilities__c.replace(';', ', ');
            row.status = r.Partner_Status__c;
            row.repFirstName = r.Rep_First_Name__c;
            row.submittedBy = r.Referring_Agent__r?.Name;
            row.submittedAt = r.CreatedDate;
            row.urgent = r.Is_Urgent__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getHomeSummary() {
        PR_SystemData.PortalContext ctx = PR_SystemData.currentContext();
        Boolean principal = FeatureManagement.checkPermission(PR_Settings.PERM_PRINCIPAL);
        Map<String, Integer> byStatus = new Map<String, Integer>();
        for (String s : new List<String>{ PR_Settings.REF_RECEIVED, PR_Settings.REF_IN_PROGRESS, PR_Settings.REF_CONNECTED, PR_Settings.REF_CLOSED_LOST }) {
            byStatus.put(s, 0);
        }
        Integer total = 0;
        for (AggregateResult ar : [
            SELECT Partner_Status__c st, COUNT(Id) cnt
            FROM Referral__c
            WHERE CreatedDate = THIS_MONTH
            WITH USER_MODE
            GROUP BY Partner_Status__c
        ]) {
            Integer c = (Integer) ar.get('cnt');
            byStatus.put((String) ar.get('st'), c);
            total += c;
        }
        Map<String, Object> out = new Map<String, Object>{
            'agencyName' => ctx.agencyName,
            'isPrincipal' => principal,
            'byStatus' => byStatus,
            'totalThisMonth' => total
        };
        if (principal) {
            out.put('commissionThisMonth', commissionTotal(true));
            out.put('commissionLastMonth', commissionTotal(false));
        }
        return out;
    }

    /** Summed in Apex: SUM() on a currency field returns the corporate currency (AED), not AUD. */
    private static Decimal commissionTotal(Boolean thisMonth) {
        String soql =
            'SELECT Amount__c FROM Partner_Commission__c WHERE Status__c != \'Cancelled\' AND CreatedDate = ' +
            (thisMonth ? 'THIS_MONTH' : 'LAST_MONTH') + ' LIMIT 5000';
        Decimal total = 0;
        for (Partner_Commission__c c : (List<Partner_Commission__c>) Database.query(soql, AccessLevel.USER_MODE)) {
            total += c.Amount__c == null ? 0 : c.Amount__c;
        }
        return total;
    }
}
