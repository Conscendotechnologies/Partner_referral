/**
 * Pulls Workday workers into Contacts, one page per Queueable so every page
 * gets its own callout and DML limits. When the last page is processed, any
 * Workday contact the run did not touch is marked inactive.
 *
 * Runs without sharing: it is a system sync and must see every Workday contact
 * regardless of owner to upsert and deactivate correctly.
 */
public without sharing class WorkdayWorkerSyncJob implements Queueable, Database.AllowsCallouts {

    /** Set while the sync writes contacts, so those writes are not pushed back to Workday. */
    public static Boolean isSyncing = false;

    private final Integer offset;
    private final Datetime syncStart;

    public WorkdayWorkerSyncJob() {
        this(0, Datetime.now());
    }

    private WorkdayWorkerSyncJob(Integer offset, Datetime syncStart) {
        this.offset = offset;
        this.syncStart = syncStart;
    }

    /** Starts a full sync and returns the first job id. */
    public static Id start() {
        return System.enqueueJob(new WorkdayWorkerSyncJob());
    }

    public void execute(QueueableContext context) {
        isSyncing = true;
        WorkdayClient client = new WorkdayClient();
        Workday_Setting__mdt settings = client.getSettings();
        Integer pageSize = Math.min(100, Math.max(1, settings.Page_Size__c.intValue()));

        WorkdayClient.WorkersPage page = client.getWorkers(offset, pageSize);
        Id accountId = workerAccountId(settings.Account_Name__c);

        List<Contact> contacts = new List<Contact>();
        for (Map<String, Object> worker : page.workers) {
            Contact c = toContact(worker, accountId);
            if (c != null) {
                contacts.add(c);
            }
        }

        List<Database.UpsertResult> results =
            Database.upsert(contacts, Contact.Workday_ID__c, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.WARN, 'Workday sync skipped worker '
                    + contacts[i].Workday_ID__c + ': ' + results[i].getErrors()[0].getMessage());
            }
        }

        Integer nextOffset = offset + page.workers.size();
        if (!page.workers.isEmpty() && nextOffset < page.total) {
            System.enqueueJob(new WorkdayWorkerSyncJob(nextOffset, syncStart));
        } else {
            deactivateMissing(syncStart);
        }
    }

    /** Maps one Workday worker JSON object onto a Contact, or null if it has no id. */
    public static Contact toContact(Map<String, Object> worker, Id accountId) {
        String workdayId = (String) worker.get('id');
        if (String.isBlank(workdayId)) {
            return null;
        }

        String fullName = String.isBlank((String) worker.get('descriptor'))
            ? workdayId : ((String) worker.get('descriptor')).trim();
        Integer split = fullName.lastIndexOf(' ');

        Contact c = new Contact(
            Workday_ID__c = workdayId,
            FirstName = split > 0 ? fullName.left(split) : null,
            LastName = split > 0 ? fullName.substring(split + 1) : fullName,
            Workday_Employee_ID__c = firstString(worker, new List<String>{ 'workerId', 'employeeId' }),
            Email = firstString(worker, new List<String>{ 'primaryWorkEmail', 'email' }),
            Phone = firstString(worker, new List<String>{ 'primaryWorkPhone' }),
            Title = firstString(worker, new List<String>{ 'businessTitle' }),
            Workday_Supervisory_Org__c = descriptorOf(worker.get('primarySupervisoryOrganization')),
            Workday_Active__c = true,
            Workday_Last_Synced__c = Datetime.now()
        );
        c.Department = c.Workday_Supervisory_Org__c == null ? null : c.Workday_Supervisory_Org__c.left(80);
        if (accountId != null) {
            c.AccountId = accountId;
        }
        return c;
    }

    private static void deactivateMissing(Datetime syncStart) {
        List<Contact> stale = [
            SELECT Id FROM Contact
            WHERE Workday_ID__c != null
              AND Workday_Active__c = true
              AND (Workday_Last_Synced__c = null OR Workday_Last_Synced__c < :syncStart)
            LIMIT 10000
        ];
        for (Contact c : stale) {
            c.Workday_Active__c = false;
        }
        Database.update(stale, false);
    }

    private static Id workerAccountId(String accountName) {
        if (String.isBlank(accountName)) {
            return null;
        }
        List<Account> existing = [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        Account a = new Account(Name = accountName);
        insert a;
        return a.Id;
    }

    private static String firstString(Map<String, Object> source, List<String> keys) {
        for (String key : keys) {
            Object value = source.get(key);
            if (value instanceof String && String.isNotBlank((String) value)) {
                return (String) value;
            }
            String nested = descriptorOf(value);
            if (nested != null) {
                return nested;
            }
        }
        return null;
    }

    /** Workday references come back as { id, descriptor, href }. */
    private static String descriptorOf(Object value) {
        if (value instanceof Map<String, Object>) {
            Object descriptor = ((Map<String, Object>) value).get('descriptor');
            return descriptor instanceof String ? (String) descriptor : null;
        }
        return null;
    }
}
