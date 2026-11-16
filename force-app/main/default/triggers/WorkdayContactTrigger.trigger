/**
 * Salesforce -> Workday: when a user changes the Title of a Workday-linked
 * contact, push it to Workday. Writes made by the Workday sync are skipped.
 */
trigger WorkdayContactTrigger on Contact (after update) {
    if (WorkdayWorkerSyncJob.isSyncing) {
        return;
    }
    List<Id> changed = new List<Id>();
    for (Contact c : Trigger.new) {
        Contact old = Trigger.oldMap.get(c.Id);
        if (c.Workday_ID__c != null && String.isNotBlank(c.Title) && c.Title != old.Title) {
            changed.add(c.Id);
        }
    }
    if (!changed.isEmpty()) {
        System.enqueueJob(new WorkdayTitlePushJob(changed));
    }
}
