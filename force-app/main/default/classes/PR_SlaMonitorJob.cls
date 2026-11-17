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

    @TestVisible
    private static Integer MAX_PER_RUN = 2000;

    public static Integer run() {
        Id rt = PR_Settings.leadRecordTypeId();
        Datetime now = System.now();
        Date urgentFrom = Date.today().addDays((Integer) Math.ceil((PR_Settings.get().Urgent_Window_Hours__c == null ? 48 : PR_Settings.get().Urgent_Window_Hours__c) / 24));
        // One cap for the whole run: 2,000 leads = 10 trigger chunks of 200, and PR_Notifier sends at most one
        // email batch per chunk, so a run stays within the 10 sendEmail calls per transaction. Newly urgent
        // movers go first (soonest move-in first), so a breach backlog can never starve them; the hourly
        // schedule picks up whatever is left.
        Map<Id, Lead> touch = new Map<Id, Lead>();
        for (Lead l : [
            SELECT Id
            FROM Lead
            WHERE RecordTypeId = :rt AND IsConverted = FALSE AND Is_Urgent__c = FALSE AND Move_In_Date__c <= :urgentFrom
            ORDER BY Move_In_Date__c ASC
            LIMIT :MAX_PER_RUN
        ]) {
            touch.put(l.Id, new Lead(Id = l.Id));
        }
        Integer room = MAX_PER_RUN - touch.size();
        if (room > 0) {
            for (Lead l : [
                SELECT Id
                FROM Lead
                WHERE RecordTypeId = :rt AND IsConverted = FALSE AND SLA_Breached__c = FALSE
                    AND First_Contacted_At__c = NULL AND SLA_Due_At__c < :now AND Id NOT IN :touch.keySet()
                ORDER BY SLA_Due_At__c ASC
                LIMIT :room
            ]) {
                touch.put(l.Id, new Lead(Id = l.Id));
            }
        }
        // The Lead trigger recalculates urgency and SLA breach on every save.
        Database.update(touch.values(), false);
        return touch.size();
    }
}
