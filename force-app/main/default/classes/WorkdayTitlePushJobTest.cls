@IsTest
private class WorkdayTitlePushJobTest {

    /** POST creates the title change; GET returns the worker with workerTitle. */
    private class TitleMock implements HttpCalloutMock {
        String workerTitle;
        Integer postStatus = 201;
        String postedBody;

        TitleMock(String workerTitle) {
            this.workerTitle = workerTitle;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'POST') {
                System.assert(req.getEndpoint().endsWith('/common/v1/workers/wd-1/businessTitleChanges'), req.getEndpoint());
                postedBody = req.getBody();
                res.setStatusCode(postStatus);
                res.setBody(postStatus == 201 ? '{"id":"chg-1"}' : '{"error":"permission denied"}');
            } else {
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{ 'id' => 'wd-1', 'businessTitle' => workerTitle }));
            }
            return res;
        }
    }

    @TestSetup
    static void setup() {
        insert new Contact(LastName = 'Cortes', Title = 'Senior Recruiter', Workday_ID__c = 'wd-1');
    }

    private static Contact editTitle(String title) {
        Contact c = [SELECT Id FROM Contact WHERE Workday_ID__c = 'wd-1'];
        c.Title = title;
        Test.startTest();
        update c;
        Test.stopTest();
        return [SELECT Workday_Push_Status__c, Workday_Last_Pushed__c FROM Contact WHERE Id = :c.Id];
    }

    @IsTest
    static void titleEditIsAppliedInWorkday() {
        TitleMock mock = new TitleMock('Lead Recruiter');
        Test.setMock(HttpCalloutMock.class, mock);
        Contact c = editTitle('Lead Recruiter');
        System.assertEquals(WorkdayTitlePushJob.APPLIED, c.Workday_Push_Status__c);
        System.assertNotEquals(null, c.Workday_Last_Pushed__c);
        System.assert(mock.postedBody.contains('"proposedBusinessTitle":"Lead Recruiter"'), mock.postedBody);
    }

    @IsTest
    static void titleAwaitingApprovalIsReportedPending() {
        Test.setMock(HttpCalloutMock.class, new TitleMock('Senior Recruiter'));
        System.assertEquals(WorkdayTitlePushJob.PENDING, editTitle('Lead Recruiter').Workday_Push_Status__c);
    }

    @IsTest
    static void workdayErrorIsRecorded() {
        TitleMock mock = new TitleMock('Senior Recruiter');
        mock.postStatus = 403;
        Test.setMock(HttpCalloutMock.class, mock);
        String status = editTitle('Lead Recruiter').Workday_Push_Status__c;
        System.assert(status.startsWith('Failed:') && status.contains('403'), status);
    }

    @IsTest
    static void syncWritesAreNotPushedBack() {
        Contact c = [SELECT Id FROM Contact WHERE Workday_ID__c = 'wd-1'];
        WorkdayWorkerSyncJob.isSyncing = true;
        c.Title = 'From Workday';
        update c;
        System.assertEquals(0, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'WorkdayTitlePushJob']);
    }
}
