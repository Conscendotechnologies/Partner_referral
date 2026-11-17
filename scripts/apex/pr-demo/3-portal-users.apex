// 002 Partner referral demo, step 3 of 6 (setup objects only): enables partner logins for the demo agents,
// the same as a Partner Manager clicking "Enable Partner User". PR_UserTrigger picks the partner role and
// permission set from the contact's Portal Role. Passwords are set in 6-site-passwords.apex, after the site
// membership exists (setPassword fails for portal users who are not in a site yet). Safe to re-run.
String suffix = '@connectnow-partners.demo';
Id profileId = [SELECT Id FROM Profile WHERE Name = 'Connectnow Partner User' LIMIT 1].Id;

// Exactly which demo contacts get a login: agency + first name + last name, so a same-named contact at another
// agency can never be picked up (and collide on the username).
List<List<String>> wanted = new List<List<String>>{
    new List<String>{ 'Harbour & Co Realty', 'Priya', 'Shah' },
    new List<String>{ 'Harbour & Co Realty', 'Tom', 'Nguyen' },
    new List<String>{ 'Bayside Property Group', 'Marco', 'Rossi' },
    new List<String>{ 'Bayside Property Group', 'Chloe', 'Tan' }
};
Set<String> agencies = new Set<String>();
Set<String> firstNames = new Set<String>();
for (List<String> w : wanted) {
    agencies.add(w[0]);
    firstNames.add(w[1]);
}
Map<String, List<Contact>> byKey = new Map<String, List<Contact>>();
for (Contact c : [
    SELECT Id, FirstName, LastName, Email, Account.Name
    FROM Contact
    WHERE Account.Name IN :agencies AND FirstName IN :firstNames AND Portal_Role__c != null
]) {
    String key = c.Account.Name + '|' + c.FirstName + '|' + c.LastName;
    if (!byKey.containsKey(key)) byKey.put(key, new List<Contact>());
    byKey.get(key).add(c);
}

// Check every wanted contact before inserting anything: none missing, none ambiguous.
List<String> problems = new List<String>();
List<Contact> targets = new List<Contact>();
for (List<String> w : wanted) {
    String key = w[0] + '|' + w[1] + '|' + w[2];
    List<Contact> found = byKey.get(key);
    if (found == null) {
        problems.add('missing ' + w[1] + ' ' + w[2] + ' at ' + w[0] + ' (run 2-agencies-and-products.apex first)');
    } else if (found.size() > 1) {
        problems.add(found.size() + ' contacts named ' + w[1] + ' ' + w[2] + ' at ' + w[0]);
    } else {
        targets.add(found[0]);
    }
}
if (!problems.isEmpty()) {
    throw new IllegalArgumentException('Demo contacts not usable, nothing created: ' + String.join(problems, '; '));
}

Set<Id> haveLogin = new Set<Id>();
for (User u : [SELECT ContactId FROM User WHERE ContactId IN :targets]) haveLogin.add(u.ContactId);
List<User> users = new List<User>();
for (Contact c : targets) {
    if (haveLogin.contains(c.Id)) continue;
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
System.debug('PR-DEMO step 3 done: ' + users.size() + ' new partner users');
for (User u : [SELECT Username FROM User WHERE Username LIKE :('%' + suffix)]) System.debug('PR-DEMO-USER ' + u.Username);
