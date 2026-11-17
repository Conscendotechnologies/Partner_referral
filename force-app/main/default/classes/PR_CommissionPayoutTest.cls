@IsTest
private class PR_CommissionPayoutTest {
    @TestSetup
    static void setup() {
        PR_TestFactory.buildWorld();
    }

    /** Commissions without an Opportunity, created the way the service does (bypassing locks). */
    private static List<Partner_Commission__c> commissions(String agencyName, Integer count, String status) {
        Account a = PR_TestFactory.agencyByName(agencyName);
        List<Partner_Commission__c> cs = new List<Partner_Commission__c>();
        for (Integer i = 0; i < count; i++) {
            Partner_Commission__c c = new Partner_Commission__c(Agency__c = a.Id, Rate_Applied__c = a.Commission_Rate__c, Services_Count__c = 2, Amount__c = a.Commission_Rate__c * 2, Status__c = status);
            c.put('CurrencyIsoCode', 'AUD');
            cs.add(c);
        }
        PR_CommissionService.withBypass(cs, true);
        return cs;
    }

    @IsTest
    static void approvalNeedsPermissionAndStampsApprover() {
        Partner_Commission__c c = commissions(PR_TestFactory.AGENCY_A, 1, 'Pending')[0];
        System.runAs(PR_TestFactory.user('prrep')) {
            Database.SaveResult sr = Database.update(new Partner_Commission__c(Id = c.Id, Status__c = 'Approved'), false);
            Assert.isFalse(sr.isSuccess(), 'sales rep cannot approve');
        }
        User mgr = PR_TestFactory.user('prmgr');
        System.runAs(mgr) {
            update new Partner_Commission__c(Id = c.Id, Status__c = 'Approved');
            Partner_Commission__c after = [SELECT Approved_By__c, Approved_On__c FROM Partner_Commission__c WHERE Id = :c.Id];
            Assert.areEqual(mgr.Id, after.Approved_By__c);
            Assert.isNotNull(after.Approved_On__c);

            Database.SaveResult locked = Database.update(new Partner_Commission__c(Id = c.Id, Amount__c = 999), false);
            Assert.isFalse(locked.isSuccess(), 'amount is locked');
            Database.SaveResult manualPay = Database.update(new Partner_Commission__c(Id = c.Id, Status__c = 'Paid'), false);
            Assert.isFalse(manualPay.isSuccess(), 'Paid only via payout');
            Database.SaveResult noReason = Database.update(new Partner_Commission__c(Id = c.Id, Status__c = 'Cancelled'), false);
            Assert.isFalse(noReason.isSuccess(), 'cancel needs a reason');
            update new Partner_Commission__c(Id = c.Id, Status__c = 'Pending');
            update new Partner_Commission__c(Id = c.Id, Status__c = 'Cancelled', Cancellation_Reason__c = 'Wrong rate');
            Database.SaveResult revive = Database.update(new Partner_Commission__c(Id = c.Id, Status__c = 'Pending'), false);
            Assert.isFalse(revive.isSuccess(), 'cancelled is final');
        }
    }

    @IsTest
    static void manualCreateOnlyForFinance() {
        Account a = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A);
        System.runAs(PR_TestFactory.user('prrep')) {
            Database.SaveResult sr = Database.insert(new Partner_Commission__c(Agency__c = a.Id, Amount__c = 50), false);
            Assert.isFalse(sr.isSuccess());
        }
        System.runAs(PR_TestFactory.user('prmgr')) {
            Partner_Commission__c c = new Partner_Commission__c(Agency__c = a.Id, Amount__c = 50, Status__c = 'Approved');
            insert c;
            Assert.areEqual('Pending', [SELECT Status__c FROM Partner_Commission__c WHERE Id = :c.Id].Status__c, 'always starts Pending');
        }
    }

    @IsTest
    static void reopenAfterApprovalFlagsForFinance() {
        Partner_Commission__c c = commissions(PR_TestFactory.AGENCY_A, 1, 'Approved')[0];
        Account acc = new Account(Name = 'Mover');
        insert acc;
        Opportunity o = new Opportunity(Name = 'x', AccountId = acc.Id, StageName = 'Qualification', CloseDate = Date.today());
        insert o;
        PR_CommissionService.withBypass(new List<Partner_Commission__c>{ new Partner_Commission__c(Id = c.Id, Opportunity__c = o.Id) }, false);
        PR_CommissionService.handleReopen(new Set<Id>{ o.Id });
        Partner_Commission__c after = [SELECT Status__c, Reopened_After_Approval__c FROM Partner_Commission__c WHERE Id = :c.Id];
        Assert.areEqual('Approved', after.Status__c);
        Assert.isTrue(after.Reopened_After_Approval__c);
        PR_CommissionService.createFor(new Set<Id>());
        PR_CommissionService.handleReopen(null);
    }

    @IsTest
    static void payoutGroupsPerAgencyIsIdempotentAndPays() {
        commissions(PR_TestFactory.AGENCY_A, 3, 'Approved');
        commissions(PR_TestFactory.AGENCY_B, 2, 'Approved');
        commissions(PR_TestFactory.AGENCY_B, 1, 'Pending');
        User mgr = PR_TestFactory.user('prmgr');
        Id batchId;
        Test.startTest();
        System.runAs(mgr) {
            batchId = PR_PayoutController.runPayout('2026-12');
        }
        Test.stopTest();

        List<Payout_Line__c> lines = [SELECT Agency__r.Name, Total_Ex_GST__c, Commission_Count__c, Payment_Reference__c FROM Payout_Line__c WHERE Payout_Batch__c = :batchId ORDER BY Agency__r.Name];
        Assert.areEqual(2, lines.size(), 'one line per agency');
        Assert.areEqual(300, lines[0].Total_Ex_GST__c, 'A: 3 x 100');
        Assert.areEqual('202612-12345678901', lines[0].Payment_Reference__c);
        Assert.areEqual(240, lines[1].Total_Ex_GST__c, 'B: 2 x 120');
        Assert.areEqual(5, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Included in Payout']);
        Assert.areEqual(1, [SELECT Run_Count__c FROM Payout_Batch__c WHERE Id = :batchId].Run_Count__c);

        // Re-run the same day: nothing is added twice.
        PR_PayoutService.addToBatch(batchId, [SELECT Id, Agency__c, Amount__c FROM Partner_Commission__c]);
        Assert.areEqual(300, [SELECT Total_Ex_GST__c FROM Payout_Line__c WHERE Payout_Batch__c = :batchId AND Agency__r.Name = :PR_TestFactory.AGENCY_A].Total_Ex_GST__c);

        System.runAs(mgr) {
            Map<String, Object> console = PR_PayoutController.getConsole(batchId);
            Assert.areEqual(true, console.get('canManage'));
            try {
                PR_PayoutController.markPaid(batchId);
                Assert.fail('must export first');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('CSV'));
            }
            Map<String, String> csv = PR_PayoutController.exportCsv(batchId);
            List<String> rows = csv.get('body').trim().split('\n');
            Assert.areEqual(PR_PayoutService.CSV_HEADER, rows[0]);
            Assert.areEqual(3, rows.size());
            Assert.areEqual('PR Test Agency A,12345678901,202612-12345678901,300.00,3,2026-12', rows[1]);
            Assert.areEqual('Exported', [SELECT Status__c FROM Payout_Batch__c WHERE Id = :batchId].Status__c);
            try {
                PR_PayoutController.runPayout('2026-12');
                Assert.fail('exported batch is closed');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('already'));
            }
            PR_PayoutController.markPaid(batchId);
            PR_PayoutService.markPaid(batchId);
        }
        Assert.areEqual(5, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Paid']);
        Assert.areEqual('Paid', [SELECT Status__c FROM Payout_Batch__c WHERE Id = :batchId].Status__c);
    }

    @IsTest
    static void onlyFinanceCanRunPayouts() {
        System.runAs(PR_TestFactory.user('prrep')) {
            try {
                PR_PayoutController.runPayout(null);
                Assert.fail();
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Finance'));
            }
            try {
                PR_PayoutController.exportCsv(null);
                Assert.fail();
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
    }

    @IsTest
    static void schedulerOnlyRunsOnFirstBusinessDay() {
        Assert.isTrue(PR_PayoutService.isFirstBusinessDay(Date.newInstance(2026, 12, 1)), 'Tue 1 Dec 2026');
        Assert.isFalse(PR_PayoutService.isFirstBusinessDay(Date.newInstance(2026, 11, 1)), 'Sun 1 Nov 2026');
        Assert.isTrue(PR_PayoutService.isFirstBusinessDay(Date.newInstance(2026, 11, 2)), 'Mon 2 Nov 2026');
        commissions(PR_TestFactory.AGENCY_A, 1, 'Approved');
        Test.startTest();
        new PR_PayoutBatchJob().execute(null);
        Test.stopTest();
        Integer batches = [SELECT COUNT() FROM Payout_Batch__c];
        Assert.areEqual(PR_PayoutService.isFirstBusinessDay(Date.today()) ? 1 : 0, batches);
    }
}
