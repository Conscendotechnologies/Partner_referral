// 002 Partner referral demo, step 3 of 5 (setup objects only): enables partner logins for the demo agents,
// the same as a Partner Manager clicking "Enable Partner User". PR_UserTrigger picks the partner role and
// permission set from the contact's Portal Role. Passwords are set in 6-site-passwords.apex, after the site
// membership exists (setPassword fails for portal users who are not in a site yet). Safe to re-run.
String suffix = '@connectnow-partners.demo';
Id profileId = [SELECT Id FROM Profile WHERE Name = 'Connectnow Partner User' LIMIT 1].Id;
Set<String> wanted = new Set<String>{ 'Priya Shah', 'Tom Nguyen', 'Marco Rossi', 'Chloe Tan' };
Map<Id, User> existing = new Map<Id, User>();
for (User u : [SELECT Id, ContactId FROM User WHERE Username LIKE :('%' + suffix)]) existing.put(u.ContactId, u);
List<User> users = new List<User>();
for (Contact c : [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Account.Partner_Status__c != null AND Portal_Role__c != null]) {
    if (!wanted.contains(c.FirstName + ' ' + c.LastName) || existing.containsKey(c.Id)) continue;
    String alias = (c.FirstName.left(1) + c.LastName).left(8).toLowerCase();
    User u = new User(
        ContactId = c.Id, ProfileId = profileId, FirstName = c.FirstName, LastName = c.LastName, Alias = alias,
        Email = c.Email, Username = c.FirstName.toLowerCase() + '.' + c.LastName.toLowerCase() + suffix,
        CommunityNickname = (c.FirstName + c.LastName).left(40), TimeZoneSidKey = 'Australia/Sydney',
        LocaleSidKey = 'en_AU', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
    );
    u.put('DefaultCurrencyIsoCode', 'AUD');
    users.add(u);
}
insert users;
List<User> all = [SELECT Id, Username FROM User WHERE Username LIKE :('%' + suffix)];
System.debug('PR-DEMO step 3 done: ' + users.size() + ' new partner users');
for (User u : all) System.debug('PR-DEMO-USER ' + u.Username);
