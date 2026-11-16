@IsTest
private class WorkdaySyncControllerTest {

    private class WorkersMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"total":3,"data":['
                + '{"id":"wd-1","descriptor":"Logan McNeil","primaryWorkEmail":"lmcneil@example.com",'
                + '"businessTitle":"VP, HR","primarySupervisoryOrganization":{"descriptor":"Human Resources"}},'
                + '{"id":"wd-2","descriptor":"Amy Frost","businessTitle":"Director, Field Sales"},'
                + '{"id":"wd-3","descriptor":"New Hire","businessTitle":"Analyst"}]}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        insert new List<Contact>{
            new Contact(FirstName = 'Logan', LastName = 'McNeil', Email = 'LMcNeil@example.com',
                Title = 'VP, HR', Workday_Supervisory_Org__c = 'Human Resources',
                Workday_ID__c = 'wd-1', Workday_Active__c = true, Workday_Last_Synced__c = Datetime.now()),
            new Contact(FirstName = 'Amy', LastName = 'Frost', Title = 'Sales Rep',
                Workday_ID__c = 'wd-2', Workday_Active__c = true),
            new Contact(LastName = 'Gone', Workday_ID__c = 'wd-9', Workday_Active__c = false)
        };
    }

    @IsTest
    static void compareFlagsInSyncChangedAndMissing() {
        Test.setMock(HttpCalloutMock.class, new WorkersMock());
        Test.startTest();
        WorkdaySyncController.Comparison c = WorkdaySyncController.compare();
        Test.stopTest();

        System.assertEquals(3, c.workdayTotal);
        Map<String, WorkdaySyncController.ComparisonRow> byId = new Map<String, WorkdaySyncController.ComparisonRow>();
        for (WorkdaySyncController.ComparisonRow r : c.rows) {
            byId.put(r.workdayId, r);
        }
        System.assertEquals('In sync', byId.get('wd-1').status);
        System.assertEquals('Changed', byId.get('wd-2').status);
        System.assertEquals('Title', byId.get('wd-2').changedFields);
        System.assertEquals('Missing in Salesforce', byId.get('wd-3').status);
    }

    @IsTest
    static void overviewCountsContacts() {
        WorkdaySyncController.Overview o = WorkdaySyncController.getOverview();
        System.assertEquals(2, o.activeContacts);
        System.assertEquals(1, o.inactiveContacts);
        System.assertNotEquals(null, o.lastSynced);
    }

    @IsTest
    static void syncStartsAndReportsStatus() {
        Test.setMock(HttpCalloutMock.class, new WorkersMock());
        Test.startTest();
        System.assertNotEquals(null, WorkdaySyncController.startSync());
        Test.stopTest();
        System.assertEquals('Completed', WorkdaySyncController.getSyncStatus());
        System.assertEquals('Analyst', [SELECT Title FROM Contact WHERE Workday_ID__c = 'wd-3'].Title);
    }
}
