/**
 * Apex surface for the workdayWorkerSync LWC: compares live Workday workers
 * with their Salesforce contacts and starts / tracks the sync job.
 */
public with sharing class WorkdaySyncController {

    public class Overview {
        @AuraEnabled public String tenant { get; set; }
        @AuraEnabled public Integer activeContacts { get; set; }
        @AuraEnabled public Integer inactiveContacts { get; set; }
        @AuraEnabled public Datetime lastSynced { get; set; }
    }

    public class ComparisonRow {
        @AuraEnabled public String workdayId { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String workdayTitle { get; set; }
        @AuraEnabled public String salesforceTitle { get; set; }
        @AuraEnabled public String workdayEmail { get; set; }
        @AuraEnabled public String salesforceEmail { get; set; }
        @AuraEnabled public String workdayOrg { get; set; }
        @AuraEnabled public String salesforceOrg { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String changedFields { get; set; }
    }

    public class Comparison {
        @AuraEnabled public Integer workdayTotal { get; set; }
        @AuraEnabled public List<ComparisonRow> rows { get; set; }
    }

    @AuraEnabled
    public static Overview getOverview() {
        try {
            Overview o = new Overview();
            o.tenant = Workday_Setting__mdt.getInstance('Default')?.Tenant__c;
            o.activeContacts = [SELECT COUNT() FROM Contact WHERE Workday_ID__c != null AND Workday_Active__c = true];
            o.inactiveContacts = [SELECT COUNT() FROM Contact WHERE Workday_ID__c != null AND Workday_Active__c = false];
            List<AggregateResult> last = [SELECT MAX(Workday_Last_Synced__c) lastSynced FROM Contact WHERE Workday_ID__c != null];
            o.lastSynced = (Datetime) last[0].get('lastSynced');
            return o;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Pulls up to 100 live workers from Workday and diffs them against Salesforce. */
    @AuraEnabled
    public static Comparison compare() {
        try {
            WorkdayClient.WorkersPage page = new WorkdayClient().getWorkers(0, 100);

            Map<String, Contact> contactsByWorkdayId = new Map<String, Contact>();
            Set<String> ids = new Set<String>();
            for (Map<String, Object> w : page.workers) {
                ids.add((String) w.get('id'));
            }
            for (Contact c : [SELECT Id, Name, Title, Email, Workday_ID__c, Workday_Supervisory_Org__c
                              FROM Contact WHERE Workday_ID__c IN :ids]) {
                contactsByWorkdayId.put(c.Workday_ID__c, c);
            }

            Comparison result = new Comparison();
            result.workdayTotal = page.total;
            result.rows = new List<ComparisonRow>();
            for (Map<String, Object> w : page.workers) {
                // Map the worker exactly as the sync would, so the diff is like for like.
                Contact expected = WorkdayWorkerSyncJob.toContact(w, null);
                if (expected == null) {
                    continue;
                }
                Contact actual = contactsByWorkdayId.get(expected.Workday_ID__c);

                ComparisonRow row = new ComparisonRow();
                row.workdayId = expected.Workday_ID__c;
                row.name = String.isBlank(expected.FirstName)
                    ? expected.LastName : expected.FirstName + ' ' + expected.LastName;
                row.workdayTitle = expected.Title;
                row.workdayEmail = expected.Email;
                row.workdayOrg = expected.Workday_Supervisory_Org__c;

                if (actual == null) {
                    row.status = 'Missing in Salesforce';
                } else {
                    row.contactId = actual.Id;
                    row.salesforceTitle = actual.Title;
                    row.salesforceEmail = actual.Email;
                    row.salesforceOrg = actual.Workday_Supervisory_Org__c;

                    List<String> changed = new List<String>();
                    if (actual.Name != row.name) changed.add('Name');
                    if (actual.Title != expected.Title) changed.add('Title');
                    if (!sameText(actual.Email, expected.Email)) changed.add('Email');
                    if (actual.Workday_Supervisory_Org__c != expected.Workday_Supervisory_Org__c) changed.add('Org');
                    row.status = changed.isEmpty() ? 'In sync' : 'Changed';
                    row.changedFields = String.join(changed, ', ');
                }
                result.rows.add(row);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id startSync() {
        try {
            return WorkdayWorkerSyncJob.start();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Status of the sync run. The job chains one Queueable per page, so the run
     * is finished only when no WorkdayWorkerSyncJob is still queued or running.
     */
    @AuraEnabled
    public static String getSyncStatus() {
        Integer open = [SELECT COUNT() FROM AsyncApexJob
                        WHERE ApexClass.Name = 'WorkdayWorkerSyncJob'
                          AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')];
        if (open > 0) {
            return 'Running';
        }
        List<AsyncApexJob> last = [SELECT Status, ExtendedStatus FROM AsyncApexJob
                                   WHERE ApexClass.Name = 'WorkdayWorkerSyncJob'
                                   ORDER BY CreatedDate DESC LIMIT 1];
        if (!last.isEmpty() && last[0].Status == 'Failed') {
            return 'Failed: ' + last[0].ExtendedStatus;
        }
        return 'Completed';
    }

    private static Boolean sameText(String a, String b) {
        return (a == null ? '' : a.toLowerCase()) == (b == null ? '' : b.toLowerCase());
    }
}
