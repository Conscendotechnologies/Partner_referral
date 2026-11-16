/**
 * Salesforce -> Workday: pushes Contact title edits to Workday as Change
 * Business Title events and records the outcome on the contact. Enqueued by
 * WorkdayContactTrigger; one callout pair per contact, so keep batches small.
 */
public without sharing class WorkdayTitlePushJob implements Queueable, Database.AllowsCallouts {

    public static final String APPLIED = 'Applied in Workday';
    public static final String PENDING = 'Pending approval in Workday';

    private final List<Id> contactIds;

    public WorkdayTitlePushJob(List<Id> contactIds) {
        this.contactIds = contactIds;
    }

    public void execute(QueueableContext context) {
        WorkdayClient client = new WorkdayClient();
        List<Contact> updates = new List<Contact>();
        for (Contact c : [SELECT Id, Title, Workday_ID__c FROM Contact
                          WHERE Id IN :contactIds AND Workday_ID__c != null]) {
            String status;
            try {
                status = client.changeBusinessTitle(c.Workday_ID__c, c.Title) ? APPLIED : PENDING;
            } catch (Exception e) {
                status = ('Failed: ' + e.getMessage()).left(255);
            }
            updates.add(new Contact(Id = c.Id, Workday_Push_Status__c = status,
                Workday_Last_Pushed__c = Datetime.now()));
        }
        // Status writes must not trigger another push.
        WorkdayWorkerSyncJob.isSyncing = true;
        Database.update(updates, false);
    }
}
