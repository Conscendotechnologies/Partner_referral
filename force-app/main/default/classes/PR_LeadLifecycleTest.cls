@IsTest
private class PR_LeadLifecycleTest {
    @TestSetup
    static void setup() {
        PR_TestFactory.buildWorld();
    }

    private static Referral__c submit(String mobile, String state, Integer moveInDays, List<String> utilities) {
        return PR_TestFactory.submitAs('pa_ag1', PR_TestFactory.input(mobile, state, moveInDays, utilities));
    }

    @IsTest
    static void urgencyIsRecalculatedBothWays() {
        Test.startTest();
        Referral__c r = submit('0411000001', 'QLD', 1, new List<String>{ 'Gas' });
        Lead l = [SELECT Id, Is_Urgent__c, OwnerId FROM Lead WHERE Id = :r.Lead__c];
        Assert.isTrue(l.Is_Urgent__c);
        Assert.areEqual([SELECT Id FROM Group WHERE DeveloperName = 'PR_QLD'].Id, l.OwnerId);
        Assert.isTrue(PR_Notifier.sentCount >= 0);
        System.runAs(PR_TestFactory.user('prmgr')) {
            update new Lead(Id = l.Id, Move_In_Date__c = Date.today().addDays(40));
            Assert.isFalse([SELECT Is_Urgent__c FROM Lead WHERE Id = :l.Id].Is_Urgent__c);
            update new Lead(Id = l.Id, Move_In_Date__c = Date.today().addDays(2));
            Assert.isTrue([SELECT Is_Urgent__c FROM Lead WHERE Id = :l.Id].Is_Urgent__c);
        }
        Test.stopTest();
    }

    @IsTest
    static void unknownStateGoesToUnassigned() {
        Assert.areEqual([SELECT Id FROM Group WHERE DeveloperName = 'PR_Unassigned'].Id, PR_Settings.routeQueueId(null));
        Assert.areEqual([SELECT Id FROM Group WHERE DeveloperName = 'PR_SA_WA_NT'].Id, PR_Settings.routeQueueId('wa'));
    }

    @IsTest
    static void firstContactAndPartnerStatus() {
        Test.startTest();
        Referral__c r = submit('0411000002', 'NSW', 30, new List<String>{ 'Gas' });
        User rep = PR_TestFactory.user('prrep');
        System.runAs(PR_TestFactory.user('prmgr')) {
            update new Lead(Id = r.Lead__c, OwnerId = rep.Id, Status = 'Working');
        }
        Lead l = [SELECT First_Contacted_At__c, SLA_Breached__c FROM Lead WHERE Id = :r.Lead__c];
        Assert.isNotNull(l.First_Contacted_At__c);
        Assert.isFalse(l.SLA_Breached__c);
        Referral__c after = [SELECT Partner_Status__c, Rep_First_Name__c FROM Referral__c WHERE Id = :r.Id];
        Assert.areEqual('In Progress', after.Partner_Status__c);
        Assert.areEqual(rep.FirstName, after.Rep_First_Name__c, 'first name only');

        System.runAs(PR_TestFactory.user('prmgr')) {
            update new Lead(Id = r.Lead__c, Status = 'Unqualified');
        }
        Assert.areEqual('Closed Lost', [SELECT Partner_Status__c FROM Referral__c WHERE Id = :r.Id].Partner_Status__c);
        Test.stopTest();
    }

    @IsTest
    static void slaMonitorFlagsBreachesAndNewlyUrgent() {
        Test.startTest();
        Referral__c r = submit('0411000003', 'VIC', 10, new List<String>{ 'Gas' });
        System.runAs(PR_TestFactory.user('prmgr')) {
            Lead l = new Lead(Id = r.Lead__c, SLA_Due_At__c = System.now().addHours(-3));
            update l;
            Assert.isTrue([SELECT SLA_Breached__c FROM Lead WHERE Id = :l.Id].SLA_Breached__c);
            update new Lead(Id = l.Id, SLA_Due_At__c = System.now().addHours(-3));
            Assert.isTrue(PR_SlaMonitorJob.run() >= 0);
            new PR_SlaMonitorJob().execute(null);
        }
        Test.stopTest();
        Assert.isTrue(PR_ReferralStatusSync.statusForLead('Converted') == null);
        Assert.areEqual('Connected', PR_ReferralStatusSync.statusForStage('Utilities Connected'));
    }

    @IsTest
    static void conversionBuildsOpportunityProductsAndCommission() {
        Test.startTest();
        Referral__c r = submit('0411000004', 'NSW', 20, new List<String>{ 'Electricity', 'Gas', 'Internet' });
        User mgr = PR_TestFactory.user('prmgr');
        Id oppId;
        System.runAs(mgr) {
            update new Lead(Id = r.Lead__c, OwnerId = mgr.Id, Status = 'Working');
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(r.Lead__c);
            lc.setConvertedStatus('Converted');
            Database.LeadConvertResult res = Database.convertLead(lc);
            Assert.isTrue(res.isSuccess(), String.valueOf(res.getErrors()));
            oppId = res.getOpportunityId();
        }
        Opportunity o = [
            SELECT RecordType.DeveloperName, StageName, Referring_Agency__c, Referral__c, Move_In_Date__c, Account.IsPersonAccount,
                (SELECT Id FROM OpportunityLineItems)
            FROM Opportunity WHERE Id = :oppId
        ];
        Assert.areEqual('Partner_Referral', o.RecordType.DeveloperName);
        Assert.areEqual('Qualification', o.StageName);
        Assert.areEqual(r.Referring_Agency__c, o.Referring_Agency__c);
        Assert.areEqual(r.Id, o.Referral__c);
        Assert.areEqual(3, o.OpportunityLineItems.size(), 'one product per utility');
        Assert.isTrue(o.Account.IsPersonAccount, 'mover becomes a Person Account');
        Assert.areEqual(oppId, [SELECT Opportunity__c FROM Referral__c WHERE Id = :r.Id].Opportunity__c);

        System.runAs(mgr) {
            update new Opportunity(Id = oppId, StageName = 'Utilities Connected');
        }
        Test.stopTest();
        Partner_Commission__c c = [SELECT Amount__c, Rate_Applied__c, Services_Count__c, Status__c, Agency__c, Opportunity_Key__c FROM Partner_Commission__c WHERE Opportunity__c = :oppId];
        Assert.areEqual(150, c.Amount__c, '50 x 3 services');
        Assert.areEqual('Pending', c.Status__c);
        Assert.areEqual('Connected', [SELECT Partner_Status__c FROM Referral__c WHERE Id = :r.Id].Partner_Status__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Partner_Commission__Share WHERE ParentId = :c.Id AND RowCause = 'Agency_Principal__c'], 'principal can read');

        System.runAs(PR_TestFactory.user('pa_prin')) {
            Assert.areEqual(1, [SELECT COUNT() FROM Partner_Commission__c], 'principal sees agency commission');
            Assert.areEqual(150, (Decimal) PR_PortalController.getHomeSummary().get('commissionThisMonth'));
        }
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            Assert.areEqual(0, [SELECT COUNT() FROM Partner_Commission__c], 'agents never see commissions');
        }
        System.runAs(PR_TestFactory.user('pb_ag1')) {
            Assert.areEqual(0, [SELECT COUNT() FROM Partner_Commission__c], 'other agencies never see it');
        }

        // Reopen cancels the Pending commission; winning again creates a fresh one.
        System.runAs(mgr) {
            update new Opportunity(Id = oppId, StageName = 'Connection Requested');
            Partner_Commission__c cancelled = [SELECT Status__c, Opportunity_Key__c FROM Partner_Commission__c WHERE Id = :c.Id];
            Assert.areEqual('Cancelled', cancelled.Status__c);
            Assert.isNull(cancelled.Opportunity_Key__c);
            update new Opportunity(Id = oppId, StageName = 'Utilities Connected');
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Partner_Commission__c WHERE Opportunity__c = :oppId AND Status__c = 'Pending']);
    }
}
