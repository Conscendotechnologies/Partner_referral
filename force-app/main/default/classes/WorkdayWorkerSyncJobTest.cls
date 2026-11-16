@IsTest
private class WorkdayWorkerSyncJobTest {

    /** Answers a single workers page. */
    private class WorkdayMock implements HttpCalloutMock {
        Integer workersStatus = 200;

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            System.assert(req.getEndpoint().startsWith('callout:Workday_API/'), req.getEndpoint());
            res.setStatusCode(workersStatus);
            res.setBody(workersStatus == 200
                ? '{"total":2,"data":['
                    + '{"id":"wd-1","descriptor":"Logan McNeil","workerId":"21001",'
                    + '"primaryWorkEmail":"lmcneil@example.com","businessTitle":"VP, HR",'
                    + '"primarySupervisoryOrganization":{"id":"org-1","descriptor":"Human Resources"}},'
                    + '{"id":"wd-2","descriptor":"Cher","businessTitle":"Recruiter"},'
                    + '{"descriptor":"No Id Worker"}]}'
                : '{"error":"invalid_request"}');
            return res;
        }
    }

    private static Workday_Setting__mdt settings() {
        return new Workday_Setting__mdt(
            DeveloperName = 'Default',
            Tenant__c = 'acme',
            Workers_Path__c = '/api/staffing/v6/{tenant}/workers',
            Account_Name__c = 'Workday Workers',
            Page_Size__c = 100
        );
    }

    @IsTest
    static void syncUpsertsWorkersAndDeactivatesMissing() {
        Contact leaver = new Contact(LastName = 'Leaver', Workday_ID__c = 'wd-gone',
            Workday_Active__c = true, Workday_Last_Synced__c = Datetime.now().addDays(-1));
        insert leaver;

        Test.setMock(HttpCalloutMock.class, new WorkdayMock());
        Test.startTest();
        WorkdayWorkerSyncJob.start();
        Test.stopTest();

        Contact logan = [SELECT FirstName, LastName, Email, Title, Workday_Employee_ID__c,
                         Workday_Supervisory_Org__c, Department, Workday_Active__c, Account.Name
                         FROM Contact WHERE Workday_ID__c = 'wd-1'];
        System.assertEquals('Logan', logan.FirstName);
        System.assertEquals('McNeil', logan.LastName);
        System.assertEquals('lmcneil@example.com', logan.Email);
        System.assertEquals('VP, HR', logan.Title);
        System.assertEquals('21001', logan.Workday_Employee_ID__c);
        System.assertEquals('Human Resources', logan.Workday_Supervisory_Org__c);
        System.assertEquals(true, logan.Workday_Active__c);
        System.assertNotEquals(null, logan.Account.Name);

        Contact cher = [SELECT FirstName, LastName FROM Contact WHERE Workday_ID__c = 'wd-2'];
        System.assertEquals(null, cher.FirstName);
        System.assertEquals('Cher', cher.LastName);

        System.assertEquals(false,
            [SELECT Workday_Active__c FROM Contact WHERE Id = :leaver.Id].Workday_Active__c);
        System.assertEquals(3, [SELECT COUNT() FROM Contact WHERE Workday_ID__c != null]);
    }

    @IsTest
    static void clientRaisesOnHttpError() {
        WorkdayMock mock = new WorkdayMock();
        mock.workersStatus = 401;
        Test.setMock(HttpCalloutMock.class, mock);

        WorkdayClient client = new WorkdayClient(settings());
        try {
            client.getWorkers(0, 10);
            System.assert(false, 'Expected WorkdayException');
        } catch (WorkdayClient.WorkdayException e) {
            System.assert(e.getMessage().contains('401'), e.getMessage());
        }
    }

    @IsTest
    static void schedulerRegistersDailyJob() {
        Test.setMock(HttpCalloutMock.class, new WorkdayMock());
        Test.startTest();
        Id jobId = WorkdaySyncScheduler.scheduleDaily();
        Test.stopTest();
        System.assertEquals('0 0 2 * * ?',
            [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId].CronExpression);
    }
}
