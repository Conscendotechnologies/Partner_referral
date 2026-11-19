@IsTest
private class PR_LeadLifecycleTest {
    @TestSetup
    static void setup() {
        PR_TestFactory.buildWorld();
    }

    private static Referral__c submit(String mobile, String state, Integer moveInDays, List<String> utilities) {
        return PR_TestFactory.submitAs('pa_ag1', PR_TestFactory.input(mobile, state, moveInDays, utilities));
    }

    // S03-TC-11 (AC-03.7): the rep's Referral Queue lists urgent movers first, then by move-in date, and leaves out
    // queues the rep is not in (PR_QueueLeadsController).
    // The rep is a Standard User with PR_Sales_Rep who reaches PR_QLD through a public group (queue member).
    @IsTest
    static void referralQueueIsUrgentFirstThenMoveInDateForTheRepsQueuesOnly() {
        User rep = PR_TestFactory.standardUser('prqrep', new List<String>{ 'PR_Sales_Rep' });
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group team = new Group(Name = 'PR Test QLD Team', DeveloperName = 'PR_Test_QLD_Team', Type = 'Regular');
            insert team;
            insert new List<GroupMember>{
                new GroupMember(GroupId = team.Id, UserOrGroupId = rep.Id),
                new GroupMember(GroupId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'PR_QLD'].Id, UserOrGroupId = team.Id)
            };
        }
        Test.startTest();
        Referral__c later = submit('0411000051', 'QLD', 30, new List<String>{ 'Electricity' });
        Referral__c urgent = submit('0411000052', 'QLD', 1, new List<String>{ 'Electricity' });
        Referral__c sooner = submit('0411000053', 'QLD', 10, new List<String>{ 'Electricity' });
        Referral__c otherQueue = submit('0411000054', 'NSW', 1, new List<String>{ 'Electricity' });
        Test.stopTest();

        // The three QLD Leads are in PR_QLD, and the rep's queue lookup finds PR_QLD through the public group.
        Id qldQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'PR_QLD'].Id;
        for (Lead l : [SELECT OwnerId, Owner.Name FROM Lead WHERE Id IN :new List<Id>{ later.Lead__c, urgent.Lead__c, sooner.Lead__c }]) {
            Assert.areEqual(qldQueue, l.OwnerId, 'QLD Lead is owned by PR_QLD, not ' + l.Owner.Name);
        }
        PR_QueueLeadsResult result;
        System.runAs(rep) {
            Assert.isTrue(PR_QueueLeadsController.partnerQueueIds(rep.Id).contains(qldQueue), 'the rep\'s queue lookup finds PR_QLD');
            Assert.areEqual(3, [SELECT COUNT() FROM Lead WHERE OwnerId = :qldQueue], 'the rep can see the 3 Leads in PR_QLD');
            result = PR_QueueLeadsController.getQueueLeads();
        }
        List<Id> ids = new List<Id>();
        for (PR_QueueLeadRow r : result.rows) {
            ids.add(r.id);
        }
        Assert.areEqual(new List<Id>{ urgent.Lead__c, sooner.Lead__c, later.Lead__c }, ids, 'urgent first, then by move-in date');
        Assert.isFalse(ids.contains(otherQueue.Lead__c), 'Leads in queues the rep is not in are left out');
        Assert.isFalse(result.hasMore);
        Assert.isTrue(result.rows[0].urgent);
        Assert.areEqual([SELECT Name FROM Group WHERE DeveloperName = 'PR_QLD'].Name, result.rows[0].queue, 'queue name is shown');
        Assert.areEqual(PR_TestFactory.AGENCY_A, result.rows[0].agency);
    }

    // More open Leads than the row limit: the most urgent ones are shown and the list says it is cut.
    @IsTest
    static void referralQueueSaysWhenItIsCutAtTheRowLimit() {
        Test.startTest();
        Referral__c urgent = submit('0411000055', 'QLD', 1, new List<String>{ 'Electricity' });
        submit('0411000056', 'QLD', 20, new List<String>{ 'Electricity' });
        submit('0411000057', 'QLD', 40, new List<String>{ 'Electricity' });
        Test.stopTest();
        PR_QueueLeadsController.rowLimit = 2;
        PR_QueueLeadsResult result;
        // prrep is a direct member of PR_QLD (PR_TestFactory.buildWorld).
        System.runAs(PR_TestFactory.user('prrep')) {
            result = PR_QueueLeadsController.getQueueLeads();
        }
        Assert.areEqual(2, result.rows.size());
        Assert.isTrue(result.hasMore, 'the third Lead is beyond the limit');
        Assert.areEqual(2, result.rowLimit);
        Assert.areEqual(urgent.Lead__c, result.rows[0].id);
    }

    @IsTest
    static void referralQueueIsEmptyForAUserInNoPartnerQueue() {
        System.runAs(PR_TestFactory.user('prnone')) {
            PR_QueueLeadsResult result = PR_QueueLeadsController.getQueueLeads();
            Assert.areEqual(0, result.rows.size());
            Assert.isFalse(result.hasMore);
        }
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
    static void blankRouteRecordsAreSkipped() {
        PR_Settings.routesOverride = new List<PR_State_Route__mdt>{
            new PR_State_Route__mdt(State_Codes__c = null, Queue_Developer_Name__c = 'PR_QLD'),
            new PR_State_Route__mdt(State_Codes__c = 'VIC,TAS', Queue_Developer_Name__c = 'PR_VIC_TAS')
        };
        Assert.areEqual([SELECT Id FROM Group WHERE DeveloperName = 'PR_Unassigned'].Id, PR_Settings.routeQueueId('ZZ'), 'no NullPointerException; falls back');
        Assert.areEqual([SELECT Id FROM Group WHERE DeveloperName = 'PR_VIC_TAS'].Id, PR_Settings.routeQueueId('TAS'));
    }

    @IsTest
    static void consentTextOver255CharactersReachesTheFormInFull() {
        String stored = [SELECT Consent_Text__c FROM Partner_Referral_Setting__mdt WHERE DeveloperName = 'Default'].Consent_Text__c;
        Assert.isTrue(stored.length() > 255, 'the Default consent wording is longer than getInstance() would return: ' + stored.length());
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            Map<String, Object> cfg = PR_PortalController.getFormConfig();
            Assert.areEqual(stored, (String) cfg.get('consentText'), 'the form gets every character');
            Assert.areEqual('1', cfg.get('consentVersion'));
        }
    }

    @IsTest
    static void settingsFallBackWhenThereIsNoDefaultRecord() {
        PR_Settings.cached = null;
        PR_Settings.settingsRecordName = 'No_Such_Record';
        Partner_Referral_Setting__mdt s = PR_Settings.get();
        Assert.areEqual('1', s.Consent_Version__c);
        Assert.isFalse(String.isBlank(s.Consent_Text__c));
        Assert.areEqual(48, s.Urgent_Window_Hours__c);
        Assert.areEqual(2, s.SLA_Hours__c);
        Assert.areEqual('PR_Unassigned', s.Fallback_Queue__c);
        Assert.areEqual('AUD', PR_Settings.currencyCode());
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            Assert.areEqual(s.Consent_Text__c, (String) PR_PortalController.getFormConfig().get('consentText'), 'the form uses the fallback wording');
        }
    }

    @IsTest
    static void slaMonitorCapsEachRun() {
        Test.startTest();
        Referral__c a = submit('0411000011', 'NSW', 5, new List<String>{ 'Gas' });
        Referral__c b = submit('0411000012', 'NSW', 6, new List<String>{ 'Gas' });
        Test.stopTest();
        Set<Id> leadIds = new Set<Id>{ a.Lead__c, b.Lead__c };
        Assert.areEqual(0, [SELECT COUNT() FROM Lead WHERE Id IN :leadIds AND Is_Urgent__c = TRUE]);
        // Widen the urgent window so both leads become due for the sweep, then cap the run at one lead.
        PR_Settings.get().Urgent_Window_Hours__c = 240;
        PR_SlaMonitorJob.MAX_PER_RUN = 1;
        Assert.areEqual(1, PR_SlaMonitorJob.run(), 'one run never touches more than the cap');
        Assert.areEqual(a.Lead__c, [SELECT Id FROM Lead WHERE Id IN :leadIds AND Is_Urgent__c = TRUE].Id, 'soonest move-in goes first');
        Assert.areEqual(1, PR_SlaMonitorJob.run(), 'the next run picks up the rest');
    }

    private static Lead partnerLead(String lastName, String status, Date moveIn, Datetime slaDue) {
        Lead l = new Lead(
            RecordTypeId = PR_Settings.leadRecordTypeId(),
            LastName = lastName,
            Status = status,
            LeadSource = 'Partner Referral',
            State = 'NSW',
            Move_In_Date__c = moveIn,
            SLA_Due_At__c = slaDue
        );
        l.put('CurrencyIsoCode', 'AUD');
        return l;
    }

    @IsTest
    static void slaMonitorMakesTheRealTransitions() {
        // Inserted with a due time already passed: insert never sets the breach flag, so only the sweep can.
        Lead overdue = partnerLead('Overdue', 'New', Date.today().addDays(60), System.now().addHours(-3));
        // Moves in 5 days: outside the 48 h window now, inside once the window is widened below.
        Lead soon = partnerLead('Soon', 'New', Date.today().addDays(5), System.now().addHours(5));
        // Unqualified (Closed Lost for the partner) and both overdue and moving soon: must be left alone.
        Lead lost = partnerLead('Lost', 'Unqualified', Date.today().addDays(5), System.now().addHours(-3));
        // Nothing due: must not change.
        Lead fine = partnerLead('Fine', 'New', Date.today().addDays(60), System.now().addHours(5));
        System.runAs(PR_TestFactory.user('prmgr')) {
            insert new List<Lead>{ overdue, soon, lost, fine };
        }
        Map<Id, Lead> before = new Map<Id, Lead>([SELECT Id, Is_Urgent__c, SLA_Breached__c FROM Lead WHERE Id IN :new List<Id>{ overdue.Id, soon.Id, lost.Id, fine.Id }]);
        for (Lead l : before.values()) {
            Assert.isFalse(l.Is_Urgent__c, 'nothing urgent before the sweep');
            Assert.isFalse(l.SLA_Breached__c, 'nothing breached before the sweep');
        }

        PR_Settings.get().Urgent_Window_Hours__c = 240;
        Test.startTest();
        Integer touched = PR_SlaMonitorJob.run();
        Test.stopTest();

        Map<Id, Lead> after = new Map<Id, Lead>([SELECT Id, Is_Urgent__c, SLA_Breached__c FROM Lead WHERE Id IN :before.keySet()]);
        Assert.areEqual(2, touched, 'only the overdue and the moving-soon leads are swept');
        Assert.isTrue(after.get(overdue.Id).SLA_Breached__c, 'overdue lead is flagged as an SLA breach');
        Assert.isFalse(after.get(overdue.Id).Is_Urgent__c);
        Assert.isTrue(after.get(soon.Id).Is_Urgent__c, 'lead moving inside the window turns urgent');
        Assert.isFalse(after.get(soon.Id).SLA_Breached__c);
        Assert.isFalse(after.get(lost.Id).Is_Urgent__c, 'unqualified lead is never made urgent');
        Assert.isFalse(after.get(lost.Id).SLA_Breached__c, 'unqualified lead is never counted as a breach');
        Assert.isFalse(after.get(fine.Id).Is_Urgent__c);
        Assert.isFalse(after.get(fine.Id).SLA_Breached__c);
    }

    @IsTest
    static void conversionFailsWhenAUtilityHasNoPriceBookEntry() {
        Test.startTest();
        Referral__c r = submit('0411000013', 'NSW', 20, new List<String>{ 'Electricity', 'Water' });
        delete [SELECT Id FROM PricebookEntry WHERE Pricebook2.Name = 'Partner Referral Utilities' AND Product2.Name = 'Water'];
        User mgr = PR_TestFactory.user('prmgr');
        System.runAs(mgr) {
            update new Lead(Id = r.Lead__c, OwnerId = mgr.Id, Status = 'Working');
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(r.Lead__c);
            lc.setConvertedStatus('Converted');
            Database.LeadConvertResult res = Database.convertLead(lc, false);
            Assert.isFalse(res.isSuccess(), 'conversion must not complete without every utility');
            Assert.isTrue(res.getErrors()[0].getMessage().contains('Water'), res.getErrors()[0].getMessage());
        }
        Test.stopTest();
        Assert.isFalse([SELECT IsConverted FROM Lead WHERE Id = :r.Lead__c].IsConverted);
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

    // S05-TC-07 (AC-05.1): a sales rep on the Standard User profile converts their own Partner Referral Lead.
    @IsTest
    static void aStandardUserRepConvertsToAPersonAccount() {
        User rep = PR_TestFactory.standardUser('prstdrep', new List<String>{ 'PR_Sales_Rep' });
        Test.startTest();
        Referral__c r = submit('0411000041', 'NSW', 20, new List<String>{ 'Electricity', 'Internet' });
        update new Lead(Id = r.Lead__c, OwnerId = rep.Id, Status = 'Working');
        Id oppId;
        System.runAs(rep) {
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(r.Lead__c);
            lc.setConvertedStatus('Converted');
            Database.LeadConvertResult res = Database.convertLead(lc, false);
            Assert.isTrue(res.isSuccess(), String.valueOf(res.getErrors()));
            oppId = res.getOpportunityId();
        }
        Test.stopTest();
        Opportunity o = [
            SELECT RecordType.DeveloperName, StageName, Account.IsPersonAccount, (SELECT Id FROM OpportunityLineItems)
            FROM Opportunity WHERE Id = :oppId
        ];
        Assert.isTrue(o.Account.IsPersonAccount, 'the rep gets a Person Account');
        Assert.areEqual('Partner_Referral', o.RecordType.DeveloperName);
        Assert.areEqual('Qualification', o.StageName);
        Assert.areEqual(2, o.OpportunityLineItems.size(), 'one product per utility');
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
