/**
 * 002 Partner referral (S06): commission access for users on the Standard User profile, as in the demo org.
 * The other commission tests run as System Administrators, which hides record-sharing gaps.
 */
@IsTest
private class PR_CommissionAccessTest {
    @TestSetup
    static void setup() {
        PR_TestFactory.buildWorld();
    }

    private static User standardUser(String alias, List<String> permissionSets) {
        User u = new User(
            Alias = alias,
            Email = alias + '@pr-test.example.com',
            Username = alias + String.valueOf(Crypto.getRandomInteger()).replace('-', '') + '@pr-test.example.com',
            LastName = alias,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'Australia/Sydney',
            LocaleSidKey = 'en_AU',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        u.put('DefaultCurrencyIsoCode', 'AUD');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            PR_TestFactory.assign(u.Id, permissionSets);
        }
        return u;
    }

    /** A Pending commission owned by someone else (the running admin), created the way the service does. */
    private static Partner_Commission__c pendingCommission() {
        Account a = PR_TestFactory.agencyByName(PR_TestFactory.AGENCY_A);
        Partner_Commission__c c = new Partner_Commission__c(Agency__c = a.Id, Rate_Applied__c = a.Commission_Rate__c, Services_Count__c = 2, Amount__c = a.Commission_Rate__c * 2, Status__c = 'Pending');
        c.put('CurrencyIsoCode', 'AUD');
        PR_CommissionService.withBypass(new List<Partner_Commission__c>{ c }, true);
        return c;
    }

    // TC: S06-TC-19
    @IsTest
    static void partnerManagerOnStandardProfileApprovesACommissionTheyDoNotOwn() {
        Partner_Commission__c c = pendingCommission();
        User mgr = standardUser('prsmgr', new List<String>{ 'PR_Partner_Manager' });
        System.runAs(mgr) {
            update new Partner_Commission__c(Id = c.Id, Status__c = 'Approved');
        }
        Partner_Commission__c after = [SELECT Status__c, Approved_By__c FROM Partner_Commission__c WHERE Id = :c.Id];
        Assert.areEqual('Approved', after.Status__c);
        Assert.areEqual(mgr.Id, after.Approved_By__c);
    }

    @IsTest
    static void commissionsCannotBeDeleted() {
        Partner_Commission__c c = pendingCommission();
        User mgr = standardUser('prsmg2', new List<String>{ 'PR_Partner_Manager' });
        System.runAs(mgr) {
            Database.DeleteResult dr = Database.delete(c.Id, false);
            Assert.isFalse(dr.isSuccess(), 'a commission is cancelled, never deleted');
            Assert.isTrue(dr.getErrors()[0].getMessage().contains('cannot be deleted'));
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Partner_Commission__c WHERE Id = :c.Id]);
    }
}
