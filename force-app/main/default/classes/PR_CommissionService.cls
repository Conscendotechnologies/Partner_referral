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
        List<Partner_Commission__c> flagged = new List<Partner_Commission__c>();
        for (Partner_Commission__c c : [
            SELECT Id, Name, Status__c, Reopened_After_Approval__c
            FROM Partner_Commission__c
            WHERE Opportunity__c IN :oppIds AND Status__c != :PR_Settings.COM_CANCELLED
        ]) {
            if (c.Status__c == PR_Settings.COM_PENDING) {
                updates.add(new Partner_Commission__c(
                    Id = c.Id,
                    Status__c = PR_Settings.COM_CANCELLED,
                    Cancellation_Reason__c = REOPENED_REASON,
                    Opportunity_Key__c = null
                ));
            } else {
                updates.add(new Partner_Commission__c(Id = c.Id, Reopened_After_Approval__c = true));
                if (!c.Reopened_After_Approval__c) flagged.add(c);
            }
        }
        withBypass(updates, false);
        notifyFinance(flagged);
    }

    /** AC-06.4: cancellation reason for a Pending commission whose Opportunity is reopened. */
    public static final String REOPENED_REASON = 'Opportunity reopened';

    @TestVisible
    private static Integer financeNotifications = 0;

    /**
     * AC-06.4: tells Finance (everyone with PR_Finance) that approved commissions were reopened, so they can review a
     * clawback. One notification per call: the Opportunity trigger calls this once per 200-record chunk, so a single
     * notification covers up to 200 reopened commissions and a bulk update never floods anyone. Never blocks the save.
     */
    private static void notifyFinance(List<Partner_Commission__c> flagged) {
        if (flagged.isEmpty()) {
            return;
        }
        Set<String> recipients = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name = 'PR_Finance' AND Assignee.IsActive = TRUE
        ]) {
            recipients.add(psa.AssigneeId);
        }
        List<CustomNotificationType> types = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Partner_Commission_Reopened' LIMIT 1];
        if (recipients.isEmpty() || types.isEmpty()) {
            return;
        }
        try {
            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setNotificationTypeId(types[0].Id);
            n.setTargetId(flagged[0].Id);
            n.setTitle(flagged.size() == 1
                ? 'Approved commission ' + flagged[0].Name + ' was reopened'
                : flagged.size() + ' approved commissions were reopened');
            n.setBody('The won Opportunity was reopened after the commission was approved. Review it for a clawback; the commission is flagged "Reopened After Approval".');
            n.send(recipients);
            financeNotifications++;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'PR finance notification not sent: ' + e.getMessage());
        }
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
