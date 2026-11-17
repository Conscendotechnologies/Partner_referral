/**
 * 002 Partner referral: the bulk acceptance criteria (200-record transactions, and 3,000 commissions across 40
 * agencies for the payout run).
 */
@IsTest
private class PR_BulkTest {
    @TestSetup
    static void setup() {
        PR_TestFactory.buildWorld();
    }

    private static List<PR_ReferralInput> inputs(Integer count, Integer moveInDays) {
        List<String> states = PR_Settings.STATES;
        List<PR_ReferralInput> out = new List<PR_ReferralInput>();
        for (Integer n = 0; n < count; n++) {
            PR_ReferralInput i = PR_TestFactory.input('04' + String.valueOf(70000000 + n), states[Math.mod(n, states.size())], moveInDays, new List<String>{ 'Electricity', 'Internet' });
            i.firstName = 'Bulk' + n;
            out.add(i);
        }
        return out;
    }

    /** AC-02.12 and AC-04.8: 200 submissions in one transaction, then 200 Leads moved on together. */
    @IsTest
    static void twoHundredSubmissionsAndStatusChanges() {
        Test.startTest();
        List<PR_SubmitResult> results;
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            results = PR_ReferralService.submitAll(inputs(200, 30));
        }
        Assert.areEqual(200, results.size());
        for (PR_SubmitResult r : results) Assert.isTrue(r.saved && r.referralNumber != null);

        Map<String, Id> queues = PR_Settings.queueIdsByDeveloperName();
        List<Lead> leads = [SELECT Id, OwnerId, State, Referral__c FROM Lead WHERE Referral__c != NULL];
        Assert.areEqual(200, leads.size(), 'one Lead per referral');
        for (Lead l : leads) Assert.areEqual(PR_Settings.routeQueueId(l.State), l.OwnerId, 'routed by state');
        Assert.areEqual(200, [SELECT COUNT() FROM Referral__c WHERE Lead__c != NULL AND Partner_Status__c = 'Received']);

        // AC-04.8: 200 Leads move to Working together; every referral follows.
        User rep = PR_TestFactory.user('prrep');
        System.runAs(PR_TestFactory.user('prmgr')) {
            for (Lead l : leads) {
                l.Status = 'Working';
                l.OwnerId = rep.Id;
            }
            update leads;
        }
        Test.stopTest();
        Assert.areEqual(200, [SELECT COUNT() FROM Referral__c WHERE Partner_Status__c = 'In Progress' AND Rep_First_Name__c = :rep.FirstName]);
        Assert.areEqual(200, [SELECT COUNT() FROM Lead WHERE First_Contacted_At__c != NULL]);
    }

    /** AC-03.8: 200 Partner Referral Leads inserted directly (not through the portal) are routed, urgent and timed. */
    @IsTest
    static void twoHundredLeadsInserted() {
        List<Lead> leads = new List<Lead>();
        List<String> states = PR_Settings.STATES;
        for (Integer n = 0; n < 200; n++) {
            Lead l = new Lead(
                RecordTypeId = PR_Settings.leadRecordTypeId(),
                LastName = 'Direct' + n,
                Status = 'New',
                LeadSource = 'Partner Referral',
                State = Math.mod(n, 10) == 9 ? null : states[Math.mod(n, states.size())],
                Move_In_Date__c = Date.today().addDays(Math.mod(n, 2) == 0 ? 1 : 30)
            );
            l.put('CurrencyIsoCode', 'AUD');
            leads.add(l);
        }
        Test.startTest();
        System.runAs(PR_TestFactory.user('prmgr')) {
            insert leads;
        }
        Test.stopTest();
        Id unassigned = PR_Settings.queueIdsByDeveloperName().get('PR_Unassigned');
        for (Lead l : [SELECT OwnerId, State, Is_Urgent__c, Move_In_Date__c, SLA_Due_At__c FROM Lead WHERE Id IN :leads]) {
            Assert.areEqual(l.State == null ? unassigned : PR_Settings.routeQueueId(l.State), l.OwnerId, 'routed by state, no state to Unassigned');
            Assert.areEqual(l.Move_In_Date__c <= Date.today().addDays(2), l.Is_Urgent__c);
            Assert.isNotNull(l.SLA_Due_At__c);
        }
    }

    /** AC-05.5: 200 Leads converted together (two convertLead calls of 100, the platform maximum per call). */
    @IsTest
    static void twoHundredConversions() {
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            PR_ReferralService.submitAll(inputs(200, 30));
        }
        User mgr = PR_TestFactory.user('prmgr');
        List<Lead> leads = [SELECT Id FROM Lead WHERE Referral__c != NULL];
        Test.startTest();
        System.runAs(mgr) {
            for (Lead l : leads) l.OwnerId = mgr.Id;
            update leads;
            for (Integer start = 0; start < leads.size(); start += 100) {
                List<Database.LeadConvert> batch = new List<Database.LeadConvert>();
                for (Integer n = start; n < Math.min(start + 100, leads.size()); n++) {
                    Database.LeadConvert lc = new Database.LeadConvert();
                    lc.setLeadId(leads[n].Id);
                    lc.setConvertedStatus('Converted');
                    batch.add(lc);
                }
                for (Database.LeadConvertResult r : Database.convertLead(batch)) Assert.isTrue(r.isSuccess());
            }
        }
        Test.stopTest();
        List<Opportunity> opps = [SELECT RecordType.DeveloperName, StageName, Referral__c, Referring_Agency__c, (SELECT Id FROM OpportunityLineItems) FROM Opportunity WHERE Referral__c != NULL];
        Assert.areEqual(200, opps.size());
        for (Opportunity o : opps) {
            Assert.areEqual('Partner_Referral', o.RecordType.DeveloperName);
            Assert.areEqual('Qualification', o.StageName);
            Assert.areEqual(2, o.OpportunityLineItems.size(), 'Electricity and Internet');
            Assert.isNotNull(o.Referring_Agency__c);
        }
        Assert.areEqual(200, [SELECT COUNT() FROM Referral__c WHERE Opportunity__c != NULL]);
    }

    /** AC-06.10: 200 Opportunities reach Utilities Connected together; 200 commissions, shared with the principal. */
    @IsTest
    static void twoHundredCommissions() {
        Account agency = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A);
        Id pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Partner Referral Utilities' LIMIT 1].Id;
        Id pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :pb AND Product2.Name = 'Gas' LIMIT 1].Id;
        Account mover = new Account(Name = 'Bulk movers');
        insert mover;
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer n = 0; n < 200; n++) {
            Opportunity o = new Opportunity(
                Name = 'Bulk ' + n, AccountId = mover.Id, RecordTypeId = PR_Settings.opportunityRecordTypeId(),
                StageName = 'Connection Requested', CloseDate = Date.today(), Pricebook2Id = pb, Referring_Agency__c = agency.Id
            );
            o.put('CurrencyIsoCode', 'AUD');
            opps.add(o);
        }
        insert opps;
        List<OpportunityLineItem> lines = new List<OpportunityLineItem>();
        for (Opportunity o : opps) lines.add(new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 0));
        insert lines;
        Test.startTest();
        for (Opportunity o : opps) o.StageName = 'Utilities Connected';
        update opps;
        Test.stopTest();
        Assert.areEqual(200, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Pending' AND Amount__c = :agency.Commission_Rate__c]);
        Assert.areEqual(200, [SELECT COUNT() FROM Partner_Commission__Share WHERE RowCause = 'Agency_Principal__c']);
    }

    /** AC-07.7: 3,000 approved commissions across 40 agencies in one payout run: 40 lines, totals exact. */
    @IsTest
    static void threeThousandCommissionsAcrossFortyAgencies() {
        List<Account> agencies = new List<Account>();
        for (Integer n = 0; n < 40; n++) {
            Account a = new Account(Name = 'Bulk Agency ' + n, ABN__c = String.valueOf(10000000000L + n), Partner_Status__c = 'Active', Commission_Rate__c = 50);
            a.put('CurrencyIsoCode', 'AUD');
            agencies.add(a);
        }
        System.runAs(PR_TestFactory.user('prmgr')) {
            insert agencies;
        }
        List<Partner_Commission__c> cs = new List<Partner_Commission__c>();
        for (Integer n = 0; n < 3000; n++) {
            Partner_Commission__c c = new Partner_Commission__c(Agency__c = agencies[Math.mod(n, 40)].Id, Rate_Applied__c = 50, Services_Count__c = 1, Amount__c = 50, Status__c = 'Approved');
            c.put('CurrencyIsoCode', 'AUD');
            cs.add(c);
        }
        PR_CommissionService.withBypass(cs, true);
        Payout_Batch__c b = PR_PayoutService.getOrCreateBatch('2026-11');
        Test.startTest();
        PR_PayoutService.addToBatch(b.Id, cs);
        Test.stopTest();
        List<Payout_Line__c> lines = [SELECT Total_Ex_GST__c, Commission_Count__c FROM Payout_Line__c WHERE Payout_Batch__c = :b.Id];
        Assert.areEqual(40, lines.size(), 'one line per agency');
        for (Payout_Line__c l : lines) {
            Assert.areEqual(75, l.Commission_Count__c);
            Assert.areEqual(3750, l.Total_Ex_GST__c);
        }
        Assert.areEqual(3000, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Included in Payout']);
        Assert.areEqual(150000, [SELECT Total_Ex_GST__c FROM Payout_Batch__c WHERE Id = :b.Id].Total_Ex_GST__c);
    }

    /**
     * AC-01.7: partner users enabled together get their role and permission set. 50 users, not 200: the SDO has 60
     * Partner Community licences and test users count against them.
     */
    @IsTest
    static void partnerUsersEnabledTogether() {
        Account a = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_B);
        List<Contact> contacts = new List<Contact>();
        for (Integer n = 0; n < 50; n++) {
            contacts.add(new Contact(AccountId = a.Id, FirstName = 'Agent' + n, LastName = 'Bulk', Portal_Role__c = Math.mod(n, 10) == 0 ? 'Principal' : 'Agent'));
        }
        System.runAs(PR_TestFactory.user('prmgr')) {
            insert contacts;
        }
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PR_TestFactory.portalUsers(contacts);
        }
        Test.stopTest();
        Map<Id, User> users = new Map<Id, User>([SELECT Id, ContactId, UserRole.PortalRole FROM User WHERE ContactId IN :contacts]);
        Assert.areEqual(50, users.size());
        Map<Id, String> psByUser = new Map<Id, String>();
        for (PermissionSetAssignment p : [SELECT AssigneeId, PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId IN :users.keySet() AND PermissionSet.Name LIKE 'PR_Partner%']) {
            psByUser.put(p.AssigneeId, p.PermissionSet.Name);
        }
        Map<Id, Contact> byId = new Map<Id, Contact>(contacts);
        for (User u : users.values()) {
            Boolean principal = byId.get(u.ContactId).Portal_Role__c == 'Principal';
            Assert.areEqual(principal ? 'Executive' : 'Worker', u.UserRole.PortalRole);
            Assert.areEqual(principal ? 'PR_Partner_Principal' : 'PR_Partner_Agent', psByUser.get(u.Id));
        }
    }
}
