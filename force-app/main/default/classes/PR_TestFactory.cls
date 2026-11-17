/**
 * 002 Partner referral: test data. buildWorld() creates
 *  - prmgr: internal user (role) with Partner Manager + Sales Rep + Finance, owner of the agencies
 *  - prrep: internal sales rep, prnone: internal user with no PR permission sets
 *  - Agency A (Active, rate 50): principal pa_prin, agents pa_ag1, pa_ag2
 *  - Agency B (Active, rate 60): agent pb_ag1;  Agency C (Inactive): agent pc_ag1
 *  - "Partner Referral Utilities" price book in AUD with Electricity, Gas, Water, Internet
 */
@IsTest
public class PR_TestFactory {
    public static final String AGENCY_A = 'PR Test Agency A';
    public static final String AGENCY_B = 'PR Test Agency B';
    public static final String AGENCY_C = 'PR Test Agency C';

    public static void buildWorld() {
        UserRole role = new UserRole(Name = 'PR Test Partner Owner');
        insert role;
        User mgr = internalUser('prmgr', role.Id);
        User rep = internalUser('prrep', role.Id);
        User none = internalUser('prnone', null);
        insert new List<User>{ mgr, rep, none };
        assign(mgr.Id, new List<String>{ 'PR_Partner_Manager', 'PR_Sales_Rep', 'PR_Finance' });
        assign(rep.Id, new List<String>{ 'PR_Sales_Rep' });
        insert new GroupMember(GroupId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'PR_QLD'].Id, UserOrGroupId = rep.Id);

        Map<String, Contact> contacts = new Map<String, Contact>();
        System.runAs(mgr) {
            Account a = agency(AGENCY_A, 'Active', 50, '12345678901');
            Account b = agency(AGENCY_B, 'Active', 60, '98765432109');
            Account c = agency(AGENCY_C, 'Inactive', 50, '11122233344');
            insert new List<Account>{ a, b, c };
            update new List<Account>{ new Account(Id = a.Id, IsPartner = true), new Account(Id = b.Id, IsPartner = true), new Account(Id = c.Id, IsPartner = true) };
            contacts.put('pa_prin', agent(a.Id, 'Pat', 'Principal'));
            contacts.put('pa_ag1', agent(a.Id, 'Alex', 'Agent'));
            contacts.put('pa_ag2', agent(a.Id, 'Ash', 'Agent'));
            contacts.put('pb_ag1', agent(b.Id, 'Blair', 'Agent'));
            contacts.put('pc_ag1', agent(c.Id, 'Casey', 'Agent'));
            insert contacts.values();
            utilitiesPriceBook();
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id profileId = [SELECT Id FROM Profile WHERE Name = 'Connectnow Partner User' LIMIT 1].Id;
            List<User> portal = new List<User>();
            for (String alias : contacts.keySet()) {
                User u = baseUser(alias, profileId);
                u.ContactId = contacts.get(alias).Id;
                u.FirstName = contacts.get(alias).FirstName;
                portal.add(u);
            }
            insert portal;
        }
    }

    public static User user(String alias) {
        return [SELECT Id, FirstName, ContactId, Contact.AccountId, PortalRole, UserRole.PortalRole, UserRole.Name FROM User WHERE Alias = :alias AND Email LIKE '%@pr-test.example.com' LIMIT 1];
    }

    public static Account agencyByName(String name) {
        return [SELECT Id, Commission_Rate__c FROM Account WHERE Name = :name LIMIT 1];
    }

    private static User baseUser(String alias, Id profileId) {
        String unique = alias + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = alias,
            Email = alias + '@pr-test.example.com',
            Username = unique + '@pr-test.example.com',
            CommunityNickname = unique.left(40),
            LastName = alias,
            FirstName = 'Sam',
            ProfileId = profileId,
            TimeZoneSidKey = 'Australia/Sydney',
            LocaleSidKey = 'en_AU',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        u.put('DefaultCurrencyIsoCode', 'AUD');
        return u;
    }

    private static User internalUser(String alias, Id roleId) {
        User u = baseUser(alias, [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id);
        u.UserRoleId = roleId;
        return u;
    }

    public static void assign(Id userId, List<String> names) {
        List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
        for (PermissionSet p : [SELECT Id FROM PermissionSet WHERE Name IN :names]) {
            psas.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = p.Id));
        }
        insert psas;
    }

    private static Account agency(String name, String status, Decimal rate, String abn) {
        Account a = new Account(Name = name, Partner_Status__c = status, Commission_Rate__c = rate, ABN__c = abn, Agreement_Start_Date__c = Date.today().addMonths(-1));
        a.put('CurrencyIsoCode', 'AUD');
        return a;
    }

    private static Contact agent(Id accountId, String firstName, String role) {
        return new Contact(AccountId = accountId, FirstName = firstName, LastName = 'Tester', Email = firstName.toLowerCase() + '@agency.example.com', Portal_Role__c = role);
    }

    public static void utilitiesPriceBook() {
        List<Product2> products = new List<Product2>();
        for (String u : PR_Settings.UTILITIES) products.add(new Product2(Name = u, IsActive = true, ProductCode = 'PR-' + u.toUpperCase()));
        insert products;
        Pricebook2 pb = new Pricebook2(Name = PR_Settings.get().Price_Book_Name__c, IsActive = true);
        insert pb;
        List<PricebookEntry> std = new List<PricebookEntry>();
        List<PricebookEntry> custom = new List<PricebookEntry>();
        for (Product2 p : products) {
            PricebookEntry s = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = p.Id, UnitPrice = 0, IsActive = true);
            s.put('CurrencyIsoCode', 'AUD');
            std.add(s);
            PricebookEntry c = new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = p.Id, UnitPrice = 0, IsActive = true);
            c.put('CurrencyIsoCode', 'AUD');
            custom.add(c);
        }
        insert std;
        insert custom;
    }

    public static PR_ReferralInput input(String mobile, String state, Integer moveInDays, List<String> utilities) {
        PR_ReferralInput i = new PR_ReferralInput();
        i.firstName = 'Jordan';
        i.lastName = 'Mover';
        i.mobile = mobile;
        i.email = 'jordan.' + PR_ReferralService.normaliseMobile(mobile).right(4) + '@mover.example.com';
        i.street = '1 Harbour St';
        i.suburb = 'Sydney';
        i.state = state;
        i.postcode = '2000';
        i.moveInDate = Date.today().addDays(moveInDays);
        i.utilities = utilities;
        i.notes = 'Prefers SMS';
        i.consent = true;
        return i;
    }

    /** Submits as the given portal user and returns the saved referral with its Lead. */
    public static Referral__c submitAs(String alias, PR_ReferralInput i) {
        PR_SubmitResult r;
        System.runAs(user(alias)) {
            r = PR_ReferralService.submit(i);
        }
        return [SELECT Id, Lead__c, Partner_Status__c, Referring_Agency__c, Possible_Duplicate__c FROM Referral__c WHERE Id = :r.referralId];
    }
}
