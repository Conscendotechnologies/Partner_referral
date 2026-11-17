/**
 * 002 Partner referral (S03): hourly sweep of open Partner Referral Leads.
 * - Flags first-contact SLA breaches (not moved to Working within 2 business hours).
 * - Re-saves leads whose move-in date has come into the 48 h window, so they turn urgent and alert the queue
 *   (the "move-in minus 2 days" path).
 *   System.schedule('PR SLA monitor', '0 5 * * * ?', new PR_SlaMonitorJob());
 */
public without sharing class PR_SlaMonitorJob implements Schedulable {
    public void execute(SchedulableContext sc) {
        run();
    }

    public static Integer run() {
        Id rt = PR_Settings.leadRecordTypeId();
        Datetime now = System.now();
        Date urgentFrom = Date.today().addDays((Integer) Math.ceil((PR_Settings.get().Urgent_Window_Hours__c == null ? 48 : PR_Settings.get().Urgent_Window_Hours__c) / 24));
        Map<Id, Lead> touch = new Map<Id, Lead>();
        for (Lead l : [
            SELECT Id
            FROM Lead
            WHERE RecordTypeId = :rt AND IsConverted = FALSE AND SLA_Breached__c = FALSE
                AND First_Contacted_At__c = NULL AND SLA_Due_At__c < :now
            LIMIT 2000
        ]) {
            touch.put(l.Id, new Lead(Id = l.Id));
        }
        for (Lead l : [
            SELECT Id
            FROM Lead
            WHERE RecordTypeId = :rt AND IsConverted = FALSE AND Is_Urgent__c = FALSE AND Move_In_Date__c <= :urgentFrom
            LIMIT 2000
        ]) {
            touch.put(l.Id, new Lead(Id = l.Id));
        }
        // The Lead trigger recalculates urgency and SLA breach on every save.
        Database.update(touch.values(), false);
        return touch.size();
    }
}
