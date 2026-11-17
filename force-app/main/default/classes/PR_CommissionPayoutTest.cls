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
    static void aCommissionLandsOnOnlyOnePayoutLine() {
        Partner_Commission__c c = commissions(PR_TestFactory.AGENCY_A, 1, 'Approved')[0];
        Payout_Batch__c nov = PR_PayoutService.getOrCreateBatch('2026-11');
        Payout_Batch__c dec = PR_PayoutService.getOrCreateBatch('2026-12');
        // Both runs picked the same commission in start(); each then processes the chunk.
        List<Partner_Commission__c> scope = new List<Partner_Commission__c>{ new Partner_Commission__c(Id = c.Id) };
        PR_PayoutService.addToBatch(nov.Id, scope);
        PR_PayoutService.addToBatch(dec.Id, scope);
        List<Payout_Line__c> lines = [
            SELECT Payout_Batch__c, Commission_Count__c, Total_Ex_GST__c
            FROM Payout_Line__c
            WHERE Payout_Batch__c IN (:nov.Id, :dec.Id)
        ];
        Assert.areEqual(1, lines.size(), 'exactly one payout line includes the commission');
        Assert.areEqual(nov.Id, lines[0].Payout_Batch__c, 'the first run keeps it');
        Assert.areEqual(1, lines[0].Commission_Count__c);
        Assert.areEqual(100, lines[0].Total_Ex_GST__c);
        Partner_Commission__c after = [SELECT Status__c, Payout_Line__r.Payout_Batch__c FROM Partner_Commission__c WHERE Id = :c.Id];
        Assert.areEqual('Included in Payout', after.Status__c);
        Assert.areEqual(nov.Id, after.Payout_Line__r.Payout_Batch__c);
    }

    @IsTest
    static void weekendIsLocaleIndependent() {
        Assert.isTrue(PR_PayoutService.isWeekend(Date.newInstance(2026, 11, 1)), 'Sun 1 Nov 2026');
        Assert.isTrue(PR_PayoutService.isWeekend(Date.newInstance(2026, 11, 7)), 'Sat 7 Nov 2026');
        Assert.isFalse(PR_PayoutService.isWeekend(Date.newInstance(2026, 11, 2)), 'Mon 2 Nov 2026');
        Assert.isFalse(PR_PayoutService.isWeekend(Date.newInstance(2026, 11, 6)), 'Fri 6 Nov 2026');
        Assert.isTrue(PR_PayoutService.isWeekend(Date.newInstance(1899, 12, 31)), 'Sun before the anchor date');
        User fr = PR_TestFactory.user('prrep');
        update new User(Id = fr.Id, LocaleSidKey = 'fr_FR', LanguageLocaleKey = 'fr');
        System.runAs(new User(Id = fr.Id)) {
            Assert.isFalse(PR_PayoutService.isFirstBusinessDay(Date.newInstance(2026, 11, 1)), 'French locale: Sunday is not a business day');
            Assert.isTrue(PR_PayoutService.isFirstBusinessDay(Date.newInstance(2026, 11, 2)), 'French locale: Monday 2 Nov is');
        }
    }

    @IsTest
    static void opportunityKeyIsLocked() {
        Partner_Commission__c c = commissions(PR_TestFactory.AGENCY_A, 1, 'Approved')[0];
        PR_CommissionService.withBypass(new List<Partner_Commission__c>{ new Partner_Commission__c(Id = c.Id, Opportunity_Key__c = 'KEY-1') }, false);
        System.runAs(PR_TestFactory.user('prmgr')) {
            Database.SaveResult cleared = Database.update(new Partner_Commission__c(Id = c.Id, Opportunity_Key__c = null), false);
            Assert.isFalse(cleared.isSuccess(), 'key cannot be cleared outside a cancellation');
            update new Partner_Commission__c(Id = c.Id, Status__c = 'Pending');
            update new Partner_Commission__c(Id = c.Id, Status__c = 'Cancelled', Cancellation_Reason__c = 'Wrong agency');
            Assert.isNull([SELECT Opportunity_Key__c FROM Partner_Commission__c WHERE Id = :c.Id].Opportunity_Key__c, 'cancel frees the key');
            Database.SaveResult reset = Database.update(new Partner_Commission__c(Id = c.Id, Opportunity_Key__c = 'KEY-2'), false);
            Assert.isFalse(reset.isSuccess(), 'a cancelled commission cannot take a key back');
        }
    }

    /** A manual commission with the currency set explicitly, as every manual insert must now do. */
    private static Partner_Commission__c manual(Id agencyId, Decimal amount, String status, String currencyCode) {
        Partner_Commission__c c = new Partner_Commission__c(Agency__c = agencyId, Amount__c = amount, Status__c = status);
        c.put('CurrencyIsoCode', currencyCode);
        return c;
    }

    @IsTest
    static void commissionsMustBeInAud() {
        String cur = PR_Settings.currencyCode();
        Account a = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A);
        // A Finance user whose own default currency is AED: every manual insert sets AUD explicitly.
        User aedFinance = PR_TestFactory.internalUserWithCurrency('praed', 'AED', new List<String>{ 'PR_Finance', 'PR_Partner_Manager' });

        System.runAs(aedFinance) {
            // Normal path, insert with AUD set explicitly: saved as AUD.
            Partner_Commission__c normal = manual(a.Id, 50, null, cur);
            insert normal;
            Assert.areEqual(cur, [SELECT CurrencyIsoCode FROM Partner_Commission__c WHERE Id = :normal.Id].CurrencyIsoCode, 'normal insert, AUD');

            // Normal path, update to non-AUD: rejected. Update with the currency cleared (null): stamped AUD.
            Partner_Commission__c toAed = new Partner_Commission__c(Id = normal.Id);
            toAed.put('CurrencyIsoCode', 'AED');
            Assert.isFalse(Database.update(toAed, false).isSuccess(), 'normal update to AED');
            Partner_Commission__c cleared = new Partner_Commission__c(Id = normal.Id);
            cleared.put('CurrencyIsoCode', null);
            update cleared;
            Assert.areEqual(cur, [SELECT CurrencyIsoCode FROM Partner_Commission__c WHERE Id = :normal.Id].CurrencyIsoCode, 'normal update, null currency');

            // Bypass path (the services), insert with AUD: saved.
            Partner_Commission__c bypassed = manual(a.Id, 100, 'Approved', cur);
            PR_CommissionService.withBypass(new List<Partner_Commission__c>{ bypassed }, true);
            Assert.areEqual(cur, [SELECT CurrencyIsoCode FROM Partner_Commission__c WHERE Id = :bypassed.Id].CurrencyIsoCode, 'bypass insert, AUD');

            // Bypass path, update to non-AUD: rejected. Update with the currency cleared (null): stamped AUD.
            Partner_Commission__c bypassToAed = new Partner_Commission__c(Id = bypassed.Id);
            bypassToAed.put('CurrencyIsoCode', 'AED');
            try {
                PR_CommissionService.withBypass(new List<Partner_Commission__c>{ bypassToAed }, false);
                Assert.fail('bypass update to AED');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains(cur), e.getMessage());
            }
            Partner_Commission__c bypassCleared = new Partner_Commission__c(Id = bypassed.Id);
            bypassCleared.put('CurrencyIsoCode', null);
            PR_CommissionService.withBypass(new List<Partner_Commission__c>{ bypassCleared }, false);
            Assert.areEqual(cur, [SELECT CurrencyIsoCode FROM Partner_Commission__c WHERE Id = :bypassed.Id].CurrencyIsoCode, 'bypass update, null currency');
        }

        // Explicit non-AUD from a user whose default is AUD: rejected on both paths.
        System.runAs(PR_TestFactory.user('prmgr')) {
            Database.SaveResult sr = Database.insert(manual(a.Id, 50, null, 'AED'), false);
            Assert.isFalse(sr.isSuccess(), 'normal insert, AED');
            Assert.isTrue(sr.getErrors()[0].getMessage().contains(cur));
            try {
                PR_CommissionService.withBypass(new List<Partner_Commission__c>{ manual(a.Id, 100, 'Approved', 'AED') }, true);
                Assert.fail('bypass insert, AED: the bypass must not skip the currency rule');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains(cur), e.getMessage());
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Partner_Commission__c WHERE CurrencyIsoCode != :cur], 'no non-AUD commission was saved');
    }

    @IsTest
    static void aedDefaultUserCannotSaveAnAedCommission() {
        String cur = PR_Settings.currencyCode();
        Account a = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A);
        User aedFinance = PR_TestFactory.internalUserWithCurrency('praed2', 'AED', new List<String>{ 'PR_Finance', 'PR_Partner_Manager' });
        System.runAs(aedFinance) {
            Assert.areEqual('AED', UserInfo.getDefaultCurrency());

            // AED chosen explicitly by a user whose own default is AED: rejected, never relabelled as AUD.
            Database.SaveResult explicitAed = Database.insert(manual(a.Id, 50, null, 'AED'), false);
            Assert.isFalse(explicitAed.isSuccess(), 'explicit AED from an AED-default user is rejected');
            Assert.isTrue(explicitAed.getErrors()[0].getMessage().contains(cur), explicitAed.getErrors()[0].getMessage());

            try {
                PR_CommissionService.withBypass(new List<Partner_Commission__c>{ manual(a.Id, 50, 'Approved', 'AED') }, true);
                Assert.fail('bypass insert of AED from an AED-default user is rejected too');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains(cur), e.getMessage());
            }

            // Currency left blank: the platform fills in the user's AED before the trigger, so it is rejected too.
            // That is why every manual insert must set CurrencyIsoCode = AUD.
            Database.SaveResult blank = Database.insert(new Partner_Commission__c(Agency__c = a.Id, Amount__c = 50), false);
            Assert.isFalse(blank.isSuccess(), 'blank currency from an AED-default user becomes AED and is rejected');
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Partner_Commission__c WHERE CurrencyIsoCode = 'AED']);
    }

    @IsTest
    static void exportAndRerunBlockedWhileAPayoutIsRunning() {
        commissions(PR_TestFactory.AGENCY_A, 2, 'Approved');
        User mgr = PR_TestFactory.user('prmgr');
        Test.startTest();
        System.runAs(mgr) {
            Id batchId = PR_PayoutController.runPayout('2026-12');
            Assert.isTrue(PR_PayoutService.runInProgress(), 'the batch job is queued until stopTest');
            try {
                PR_PayoutController.exportCsv(batchId);
                Assert.fail('export must wait for the run');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('still processing'), e.getMessage());
            }
            try {
                PR_PayoutController.runPayout('2026-12');
                Assert.fail('a second run must wait');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('already in progress'), e.getMessage());
            }
        }
        Test.stopTest();
        Assert.isFalse(PR_PayoutService.runInProgress());
    }

    @IsTest
    static void historicalSharingIsPagedPerAgency() {
        // Agency B gets a principal too, so its commissions have an Executive role group to share with.
        Contact bPrincipal = new Contact(AccountId = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_B).Id, FirstName = 'Bree', LastName = 'Tester', Email = 'bree@agency.example.com', Portal_Role__c = 'Principal');
        System.runAs(PR_TestFactory.user('prmgr')) {
            insert bPrincipal;
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PR_TestFactory.portalUser(bPrincipal, 'pb_prin');
        }
        List<Partner_Commission__c> aComs = commissions(PR_TestFactory.AGENCY_A, 3, 'Pending');
        List<Partner_Commission__c> bComs = commissions(PR_TestFactory.AGENCY_B, 2, 'Pending');
        Set<Id> aIds = new Map<Id, Partner_Commission__c>(aComs).keySet();
        Set<Id> bIds = new Map<Id, Partner_Commission__c>(bComs).keySet();
        Set<Id> all = new Set<Id>(aIds);
        all.addAll(bIds);
        delete [SELECT Id FROM Partner_Commission__Share WHERE ParentId IN :all AND RowCause = 'Agency_Principal__c'];

        PR_CommissionSharing.PAGE = 1;
        PR_CommissionSharing.shareJobExecutions = 0;
        Test.startTest();
        PR_CommissionSharing.shareForAgencies(new Set<Id>{
            PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A).Id,
            PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_B).Id
        });
        Test.stopTest();

        Assert.areEqual(3, [SELECT COUNT() FROM Partner_Commission__Share WHERE ParentId IN :aIds AND RowCause = 'Agency_Principal__c'], 'agency A history shared');
        Assert.areEqual(2, [SELECT COUNT() FROM Partner_Commission__Share WHERE ParentId IN :bIds AND RowCause = 'Agency_Principal__c'], 'agency B history shared: the chain reached the next agency');
        Assert.isTrue(PR_CommissionSharing.shareJobExecutions > 2, 'one page per execution, so more executions than agencies: ' + PR_CommissionSharing.shareJobExecutions);
        // Each agency's shares go only to its own principals.
        Id aGroup = [SELECT Id FROM Group WHERE Type = 'Role' AND RelatedId IN (SELECT Id FROM UserRole WHERE PortalAccountId = :PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A).Id AND PortalRole = 'Executive')].Id;
        Assert.areEqual(0, [SELECT COUNT() FROM Partner_Commission__Share WHERE ParentId IN :bIds AND UserOrGroupId = :aGroup], 'no cross-agency shares');
    }

    @IsTest
    static void manualCreateOnlyForFinance() {
        Account a = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A);
        System.runAs(PR_TestFactory.user('prrep')) {
            Database.SaveResult sr = Database.insert(manual(a.Id, 50, null, PR_Settings.currencyCode()), false);
            Assert.isFalse(sr.isSuccess());
            Assert.isTrue(sr.getErrors()[0].getMessage().contains('created automatically'), 'refused for permission, not currency');
        }
        System.runAs(PR_TestFactory.user('prmgr')) {
            Partner_Commission__c c = manual(a.Id, 50, 'Approved', PR_Settings.currencyCode());
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
        Assert.areEqual(1, PR_CommissionService.financeNotifications, 'AC-06.4: Finance is notified');
        PR_CommissionService.handleReopen(new Set<Id>{ o.Id });
        Assert.areEqual(1, PR_CommissionService.financeNotifications, 'only once per commission');
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

    /** An exported payout batch holding the given number of commissions per agency. */
    private static Payout_Batch__c exportedBatch(Integer forA, Integer forB) {
        List<Partner_Commission__c> all = new List<Partner_Commission__c>();
        all.addAll(commissions(PR_TestFactory.AGENCY_A, forA, 'Approved'));
        all.addAll(commissions(PR_TestFactory.AGENCY_B, forB, 'Approved'));
        Payout_Batch__c b = PR_PayoutService.getOrCreateBatch('2026-12');
        PR_PayoutService.addToBatch(b.Id, all);
        System.runAs(PR_TestFactory.user('prmgr')) {
            PR_PayoutService.export(b.Id);
        }
        return [SELECT Id, Status__c FROM Payout_Batch__c WHERE Id = :b.Id];
    }

    @IsTest
    static void largeBatchIsMarkedPaidInTheBackground() {
        Payout_Batch__c b = exportedBatch(5, 2);
        Assert.areEqual('Exported', b.Status__c);
        Assert.areEqual(7, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Included in Payout']);
        // Lower the limit so 7 commissions count as "more than one transaction can update".
        PR_PayoutService.SYNC_LIMIT = 3;
        User mgr = PR_TestFactory.user('prmgr');
        Test.startTest();
        System.runAs(mgr) {
            Assert.areEqual('Processing', PR_PayoutController.markPaid(b.Id), 'large batch goes to the background job');
            Assert.isTrue(PR_PayoutService.markPaidInProgress());
            // Until the job has run, nothing is Paid and the batch is not marked Paid.
            Assert.areEqual('Exported', [SELECT Status__c FROM Payout_Batch__c WHERE Id = :b.Id].Status__c, 'batch not Paid before every commission is');
            Assert.areEqual(0, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Paid']);
            try {
                PR_PayoutController.markPaid(b.Id);
                Assert.fail('a second mark-paid must wait for the running one');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('already being marked Paid'), e.getMessage());
            }
        }
        Test.stopTest();
        Assert.areEqual(7, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Paid'], 'every commission is Paid');
        Assert.areEqual(0, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Included in Payout']);
        Payout_Batch__c after = [SELECT Status__c, Paid_On__c FROM Payout_Batch__c WHERE Id = :b.Id];
        Assert.areEqual('Paid', after.Status__c, 'batch Paid once all commissions are');
        // The job runs as the Finance user (Sydney time), so "today" can be a day ahead of the test runner's.
        Assert.isNotNull(after.Paid_On__c);
        Assert.isTrue(Math.abs(after.Paid_On__c.daysBetween(Date.today())) <= 1, String.valueOf(after.Paid_On__c));
        Assert.isFalse(PR_PayoutService.markPaidInProgress());
    }

    @IsTest
    static void batchStaysExportedUntilEveryCommissionIsPaid() {
        Payout_Batch__c b = exportedBatch(3, 0);
        List<Partner_Commission__c> inBatch = [SELECT Id FROM Partner_Commission__c WHERE Status__c = 'Included in Payout'];
        // Only part of the batch paid (as if a chunk failed): the batch must not be marked Paid.
        PR_PayoutService.payCommissions(new List<Partner_Commission__c>{ inBatch[0] });
        Assert.isFalse(PR_PayoutService.finishMarkPaid(b.Id));
        Assert.areEqual('Exported', [SELECT Status__c FROM Payout_Batch__c WHERE Id = :b.Id].Status__c);
        // Finance retries: the rest are paid and the batch becomes Paid.
        System.runAs(PR_TestFactory.user('prmgr')) {
            Assert.areEqual('Paid', PR_PayoutController.markPaid(b.Id), 'small remainder is paid straight away');
        }
        Assert.areEqual(3, [SELECT COUNT() FROM Partner_Commission__c WHERE Status__c = 'Paid']);
        Assert.areEqual('Paid', [SELECT Status__c FROM Payout_Batch__c WHERE Id = :b.Id].Status__c);
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
