/**
 * 002 Partner referral (S06): one Pending commission per Opportunity reaching Utilities Connected.
 * Amount = agency rate x number of products; the rate is stored on the commission. A unique Opportunity Key
 * blocks duplicates; it is cleared on cancel so a corrected commission can be created later.
 * Reopening a won Opportunity cancels a Pending commission and flags an Approved or later one for Finance.
 */
public without sharing class PR_CommissionService {
    /** Set only by this service and the payout service, so the lock rules let system updates through. */
    public static Boolean bypassLocks = false;

    public static void createFor(Set<Id> oppIds) {
        if (oppIds == null || oppIds.isEmpty()) {
            return;
        }
        Set<String> keys = new Set<String>();
        for (Id i : oppIds) keys.add(String.valueOf(i));
        Set<String> existing = new Set<String>();
        for (Partner_Commission__c c : [SELECT Opportunity_Key__c FROM Partner_Commission__c WHERE Opportunity_Key__c IN :keys]) {
            existing.add(c.Opportunity_Key__c);
        }
        List<Partner_Commission__c> toInsert = new List<Partner_Commission__c>();
        for (Opportunity o : [
            SELECT Id, Referral__c, Referring_Agency__c, Referring_Agency__r.Commission_Rate__c,
                (SELECT Id FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Id IN :oppIds
        ]) {
            if (o.Referring_Agency__c == null || existing.contains(String.valueOf(o.Id))) continue;
            Decimal rate = o.Referring_Agency__r.Commission_Rate__c == null ? 0 : o.Referring_Agency__r.Commission_Rate__c;
            Integer services = o.OpportunityLineItems.size();
            Partner_Commission__c c = new Partner_Commission__c(
                Opportunity__c = o.Id,
                Opportunity_Key__c = String.valueOf(o.Id),
                Agency__c = o.Referring_Agency__c,
                Referral__c = o.Referral__c,
                Rate_Applied__c = rate,
                Services_Count__c = services,
                Amount__c = rate * services,
                Status__c = PR_Settings.COM_PENDING
            );
            c.put('CurrencyIsoCode', PR_Settings.currencyCode());
            toInsert.add(c);
        }
        withBypass(toInsert, true);
    }

    public static void handleReopen(Set<Id> oppIds) {
        if (oppIds == null || oppIds.isEmpty()) {
            return;
        }
        List<Partner_Commission__c> updates = new List<Partner_Commission__c>();
        for (Partner_Commission__c c : [
            SELECT Id, Status__c
            FROM Partner_Commission__c
            WHERE Opportunity__c IN :oppIds AND Status__c != :PR_Settings.COM_CANCELLED
        ]) {
            if (c.Status__c == PR_Settings.COM_PENDING) {
                updates.add(new Partner_Commission__c(
                    Id = c.Id,
                    Status__c = PR_Settings.COM_CANCELLED,
                    Cancellation_Reason__c = 'Opportunity reopened before approval',
                    Opportunity_Key__c = null
                ));
            } else {
                updates.add(new Partner_Commission__c(Id = c.Id, Reopened_After_Approval__c = true));
            }
        }
        withBypass(updates, false);
    }

    public static void withBypass(List<Partner_Commission__c> records, Boolean isInsert) {
        if (records.isEmpty()) {
            return;
        }
        Boolean previous = bypassLocks;
        bypassLocks = true;
        try {
            if (isInsert) {
                insert records;
            } else {
                update records;
            }
        } finally {
            bypassLocks = previous;
        }
    }
}
