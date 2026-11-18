@IsTest
private class PR_QueueLeadsControllerTest {
    @TestSetup
    static void setup() {
        PR_TestFactory.buildWorld();
    }

    private static Referral__c submit(String mobile, String state, Integer moveInDays) {
        return PR_TestFactory.submitAs('pa_ag1', PR_TestFactory.input(mobile, state, moveInDays, new List<String>{ 'Electricity' }));
    }

    // S03-TC-11 (AC-03.7): the rep's queue lists urgent movers first, then by move-in date; other queues are left out.
    @IsTest
    static void urgentFirstThenMoveInDateForTheRepsQueuesOnly() {
        Test.startTest();
        Referral__c later = submit('0411000051', 'QLD', 30);
        Referral__c urgent = submit('0411000052', 'QLD', 1);
        Referral__c sooner = submit('0411000053', 'QLD', 10);
        Referral__c otherQueue = submit('0411000054', 'NSW', 1);
        Test.stopTest();

        // prrep is a member of PR_QLD only (PR_TestFactory.buildWorld).
        List<PR_QueueLeadsController.LeadRow> rows;
        System.runAs(PR_TestFactory.user('prrep')) {
            rows = PR_QueueLeadsController.getQueueLeads();
        }
        List<Id> ids = new List<Id>();
        for (PR_QueueLeadsController.LeadRow r : rows) {
            ids.add(r.id);
        }
        Assert.areEqual(new List<Id>{ urgent.Lead__c, sooner.Lead__c, later.Lead__c }, ids, 'urgent first, then by move-in date');
        Assert.isFalse(ids.contains(otherQueue.Lead__c), 'Leads in queues the rep is not in are left out');
        Assert.isTrue(rows[0].urgent);
        Assert.areEqual([SELECT Name FROM Group WHERE DeveloperName = 'PR_QLD'].Name, rows[0].queue, 'queue name is shown');
        Assert.areEqual(PR_TestFactory.AGENCY_A, rows[0].agency);
    }

    @IsTest
    static void aUserInNoPartnerQueueGetsAnEmptyList() {
        System.runAs(PR_TestFactory.user('prnone')) {
            Assert.areEqual(0, PR_QueueLeadsController.getQueueLeads().size());
        }
    }
}
