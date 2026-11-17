@IsTest
private class PR_ReferralServiceTest {
    @TestSetup
    static void setup() {
        PR_TestFactory.buildWorld();
    }

    @IsTest
    static void validateCatchesEveryRule() {
        PR_ReferralInput i = new PR_ReferralInput();
        i.mobile = '0298765432';
        i.email = 'not-an-email';
        i.state = 'XX';
        i.postcode = '20';
        i.moveInDate = Date.today().addMonths(7);
        i.utilities = new List<String>{ 'Cable' };
        List<String> errors = PR_ReferralService.validate(i);
        Assert.isTrue(errors.size() >= 9, String.join(errors, ' | '));
        Assert.isTrue(PR_ReferralService.validate(null).size() == 1);

        PR_ReferralInput ok = PR_TestFactory.input('0412 345 678', 'NSW', 10, new List<String>{ 'Gas' });
        Assert.areEqual(0, PR_ReferralService.validate(ok).size());
        ok.mobile = '+61412345678';
        Assert.areEqual(0, PR_ReferralService.validate(ok).size());
        ok.moveInDate = Date.today().addDays(-8);
        Assert.areEqual(1, PR_ReferralService.validate(ok).size());
    }

    @IsTest
    static void firstNameAndSuburbFitTheLeadFields() {
        PR_ReferralInput i = PR_TestFactory.input('0412345678', 'NSW', 10, new List<String>{ 'Gas' });
        i.firstName = 'A'.repeat(40);
        i.suburb = 'S'.repeat(40);
        Assert.areEqual(0, PR_ReferralService.validate(i).size(), '40 characters is allowed');
        i.firstName = 'A'.repeat(41);
        i.suburb = 'S'.repeat(41);
        List<String> errors = PR_ReferralService.validate(i);
        Assert.areEqual(2, errors.size(), String.join(errors, ' | '));
        Assert.isTrue(errors[0].contains('First name') && errors[1].contains('Suburb'));
    }

    @IsTest
    static void mobileNumbersAreCanonicalForDuplicates() {
        Assert.areEqual('0412345678', PR_ReferralService.canonicalMobile('+61 412 345 678'));
        Assert.areEqual('0412345678', PR_ReferralService.canonicalMobile('0412 345 678'));
        Assert.areEqual(new List<String>{ '0412345678', '+61412345678' }, PR_ReferralService.mobileVariants('0412345678'));

        // An older referral stored in the +61 format, before canonicalisation.
        Account a = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A);
        Referral__c legacy = new Referral__c(First_Name__c = 'Old', Last_Name__c = 'Format', Mobile__c = '+61466666666', Referring_Agency__c = a.Id);
        legacy.put('CurrencyIsoCode', 'AUD');
        insert legacy;

        PR_ReferralInput i = PR_TestFactory.input('0466 666 666', 'NSW', 20, new List<String>{ 'Gas' });
        i.email = null;
        Test.startTest();
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            PR_SubmitResult warn = PR_ReferralService.submit(i);
            Assert.isTrue(warn.duplicateWarning, 'the 04 number matches the stored +61 number');
            i.mobile = '+61466666666';
            i.acknowledgeDuplicate = true;
            Assert.isTrue(PR_ReferralService.submit(i).saved);
        }
        Referral__c other = PR_TestFactory.submitAs('pb_ag1', PR_TestFactory.input('+61 466 666 666', 'NSW', 20, new List<String>{ 'Gas' }));
        Test.stopTest();
        Assert.isTrue(other.Possible_Duplicate__c, 'cross-agency match across both formats');
        Assert.areEqual(2, [SELECT COUNT() FROM Referral__c WHERE Mobile__c = '0412345678' OR Mobile__c = '0466666666'], 'new referrals are stored in the 04 format');
        Assert.areEqual('0466666666', [SELECT MobilePhone FROM Lead WHERE Id = :other.Lead__c].MobilePhone);
    }

    @IsTest
    static void agentSubmitsAndEverythingIsStamped() {
        Test.startTest();
        Referral__c r = PR_TestFactory.submitAs('pa_ag1', PR_TestFactory.input('0411111111', 'VIC', 30, new List<String>{ 'Electricity', 'Internet' }));
        Test.stopTest();
        User agent = PR_TestFactory.user('pa_ag1');
        Referral__c full = [
            SELECT OwnerId, Referring_Agent__c, Referring_Agency__c, Consent_Given__c, Consent_Version__c, Consent_Given_At__c,
                Partner_Status__c, Utilities__c, Mobile__c, Lead__c
            FROM Referral__c WHERE Id = :r.Id
        ];
        Assert.areEqual(agent.Id, full.OwnerId);
        Assert.areEqual(agent.ContactId, full.Referring_Agent__c);
        Assert.areEqual(agent.Contact.AccountId, full.Referring_Agency__c);
        Assert.isTrue(full.Consent_Given__c);
        Assert.areEqual('1', full.Consent_Version__c);
        Assert.areEqual('Received', full.Partner_Status__c);
        Assert.areEqual('Electricity;Internet', full.Utilities__c);

        Lead l = [SELECT RecordType.DeveloperName, LeadSource, Owner.Name, OwnerId, State, Referring_Agency__c, Is_Urgent__c, SLA_Due_At__c, Status FROM Lead WHERE Id = :full.Lead__c];
        Assert.areEqual('Partner_Referral', l.RecordType.DeveloperName);
        Assert.areEqual('Partner Referral', l.LeadSource);
        Assert.areEqual([SELECT Id FROM Group WHERE DeveloperName = 'PR_VIC_TAS'].Id, l.OwnerId, 'routed by state');
        Assert.areEqual(agent.Contact.AccountId, l.Referring_Agency__c);
        Assert.isFalse(l.Is_Urgent__c);
        Assert.isNotNull(l.SLA_Due_At__c);
    }

    @IsTest
    static void inactiveAgencyAndInternalUsersCannotSubmit() {
        Test.startTest();
        try {
            PR_TestFactory.submitAs('pc_ag1', PR_TestFactory.input('0422222222', 'QLD', 5, new List<String>{ 'Water' }));
            Assert.fail('inactive agency must be blocked');
        } catch (PR_Exception e) {
            Assert.isTrue(e.getMessage().contains('not active'));
        }
        try {
            PR_ReferralService.submit(PR_TestFactory.input('0422222222', 'QLD', 5, new List<String>{ 'Water' }));
            Assert.fail('internal user must be blocked');
        } catch (PR_Exception e) {
            Assert.isTrue(e.getMessage().contains('Only partner agents'));
        }
        Test.stopTest();
    }

    @IsTest
    static void invalidInputIsRejectedServerSide() {
        PR_ReferralInput i = PR_TestFactory.input('12345', 'NSW', 5, new List<String>{ 'Gas' });
        i.consent = false;
        Test.startTest();
        try {
            PR_TestFactory.submitAs('pa_ag1', i);
            Assert.fail('expected validation error');
        } catch (PR_Exception e) {
            Assert.isTrue(e.getMessage().contains('Mobile') && e.getMessage().contains('consent'));
        }
        Test.stopTest();
    }

    @IsTest
    static void duplicatesWarnSameAgencyAndFlagOtherAgency() {
        PR_ReferralInput i = PR_TestFactory.input('0433333333', 'NSW', 20, new List<String>{ 'Gas' });
        Test.startTest();
        PR_TestFactory.submitAs('pa_ag1', i);
        PR_SubmitResult warn;
        System.runAs(PR_TestFactory.user('pa_ag2')) {
            warn = PR_ReferralService.submit(i);
            Assert.isTrue(warn.duplicateWarning);
            Assert.isFalse(warn.saved);
            Assert.areEqual(1, warn.duplicates.size());
            i.acknowledgeDuplicate = true;
            Assert.isTrue(PR_ReferralService.submit(i).saved);
        }
        i.acknowledgeDuplicate = false;
        Referral__c other = PR_TestFactory.submitAs('pb_ag1', i);
        Test.stopTest();
        Assert.isTrue(other.Possible_Duplicate__c, 'cross-agency match flagged internally');
        Assert.areEqual(3, [SELECT COUNT() FROM Referral__c]);
    }

    @IsTest
    static void agenciesAndAgentsAreIsolated() {
        Test.startTest();
        Referral__c r = PR_TestFactory.submitAs('pa_ag1', PR_TestFactory.input('0444444444', 'NSW', 20, new List<String>{ 'Gas' }));
        Test.stopTest();
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            Assert.areEqual(1, PR_PortalController.getReferrals(null).size(), 'agent sees own');
        }
        System.runAs(PR_TestFactory.user('pa_ag2')) {
            Assert.areEqual(0, PR_PortalController.getReferrals(null).size(), 'other agent in same agency sees nothing');
        }
        System.runAs(PR_TestFactory.user('pa_prin')) {
            List<PR_ReferralRow> rows = PR_PortalController.getReferrals(null);
            Assert.areEqual(1, rows.size(), 'principal sees whole agency');
            Assert.areEqual('Alex Tester', rows[0].submittedBy);
        }
        System.runAs(PR_TestFactory.user('pb_ag1')) {
            Assert.areEqual(0, PR_PortalController.getReferrals(null).size(), 'other agency sees nothing');
            Assert.areEqual(0, [SELECT COUNT() FROM Lead WHERE Id = :r.Lead__c], 'partners have no Lead access');
        }
    }

    @IsTest
    static void portalControllerEndpoints() {
        Test.startTest();
        System.runAs(PR_TestFactory.user('pa_ag1')) {
            Map<String, Object> cfg = PR_PortalController.getFormConfig();
            Assert.areEqual(true, cfg.get('agencyActive'));
            Assert.areEqual(PR_TestFactory.AGENCY_A, cfg.get('agencyName'));
            PR_SubmitResult res = PR_PortalController.submitReferral(PR_TestFactory.input('0455555555', 'SA', 1, new List<String>{ 'Water' }));
            Assert.isTrue(res.saved);
            Assert.isNotNull(res.referralNumber);
            try {
                PR_PortalController.submitReferral(PR_TestFactory.input('bad', 'SA', 1, new List<String>{ 'Water' }));
                Assert.fail();
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Mobile'));
            }
            Map<String, Object> home = PR_PortalController.getHomeSummary();
            Assert.areEqual(1, home.get('totalThisMonth'));
            Assert.areEqual(false, home.get('isPrincipal'));
            Assert.areEqual(1, PR_PortalController.getReferrals('Received').size());
        }
        System.runAs(PR_TestFactory.user('pa_prin')) {
            Map<String, Object> home = PR_PortalController.getHomeSummary();
            Assert.areEqual(true, home.get('isPrincipal'));
            Assert.areEqual(0, (Decimal) home.get('commissionThisMonth'));
        }
        Test.stopTest();
    }

    @IsTest
    static void portalUsersGetRoleAndPermissionSet() {
        User prin = PR_TestFactory.user('pa_prin');
        User ag = PR_TestFactory.user('pa_ag1');
        Assert.areEqual('Executive', prin.UserRole.PortalRole, prin.UserRole.Name + ' / ' + prin.PortalRole);
        Assert.areEqual('Worker', ag.UserRole.PortalRole, ag.UserRole.Name);
        Assert.areEqual(1, [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :prin.Id AND PermissionSet.Name = 'PR_Partner_Principal']);
        Assert.areEqual(1, [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :ag.Id AND PermissionSet.Name = 'PR_Partner_Agent']);
    }
}
