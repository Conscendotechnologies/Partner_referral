// 002 Partner referral demo, step 2 of 5: utilities price book (AUD), agencies and their agents. Safe to re-run.
// Needs step 1 (Manage_Partner_Agencies permission, admin role).
String cur = 'AUD';
String pbName = 'Partner Referral Utilities';
List<String> utilities = new List<String>{ 'Electricity', 'Gas', 'Water', 'Internet' };

Map<String, Product2> products = new Map<String, Product2>();
for (Product2 p : [SELECT Id, Name FROM Product2 WHERE ProductCode LIKE 'PR-%']) products.put(p.Name, p);
for (String u : utilities) {
    if (!products.containsKey(u)) products.put(u, new Product2(Name = u, ProductCode = 'PR-' + u.toUpperCase(), IsActive = true, Family = 'Partner Referral Utilities'));
}
upsert products.values();

List<Pricebook2> pbs = [SELECT Id FROM Pricebook2 WHERE Name = :pbName LIMIT 1];
Pricebook2 pb = pbs.isEmpty() ? new Pricebook2(Name = pbName, IsActive = true, Description = '002 Partner referral: one line per utility, price set when the plan is chosen') : pbs[0];
if (pb.Id == null) insert pb;
Id stdId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
Set<String> existing = new Set<String>();
for (PricebookEntry e : [SELECT Pricebook2Id, Product2Id FROM PricebookEntry WHERE Product2Id IN :products.values() AND CurrencyIsoCode = :cur]) {
    existing.add(e.Pricebook2Id + '|' + e.Product2Id);
}
List<PricebookEntry> std = new List<PricebookEntry>();
List<PricebookEntry> custom = new List<PricebookEntry>();
for (Product2 p : products.values()) {
    if (!existing.contains(stdId + '|' + p.Id)) {
        PricebookEntry e = new PricebookEntry(Pricebook2Id = stdId, Product2Id = p.Id, UnitPrice = 0, IsActive = true);
        e.put('CurrencyIsoCode', cur);
        std.add(e);
    }
    if (!existing.contains(pb.Id + '|' + p.Id)) {
        PricebookEntry e = new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = p.Id, UnitPrice = 0, IsActive = true);
        e.put('CurrencyIsoCode', cur);
        custom.add(e);
    }
}
insert std;
insert custom;

// name => [status, rate, ABN]
Map<String, List<Object>> agencyDefs = new Map<String, List<Object>>{
    'Harbour & Co Realty' => new List<Object>{ 'Active', 50, '51824753556' },
    'Bayside Property Group' => new List<Object>{ 'Active', 60, '33102417032' },
    'Northside Homes' => new List<Object>{ 'Active', 75, '86000006432' },
    'Westgate Estates' => new List<Object>{ 'Onboarding', 50, '12004044937' }
};
Map<String, Account> agencies = new Map<String, Account>();
for (Account a : [SELECT Id, Name FROM Account WHERE Name IN :agencyDefs.keySet()]) agencies.put(a.Name, a);
for (String name : agencyDefs.keySet()) {
    if (agencies.containsKey(name)) continue;
    List<Object> d = agencyDefs.get(name);
    Account a = new Account(RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business_Account').getRecordTypeId(), Name = name, Partner_Status__c = (String) d[0], Commission_Rate__c = (Integer) d[1], ABN__c = (String) d[2],
        Agreement_Start_Date__c = Date.newInstance(2026, 11, 1), BillingState = 'NSW', BillingCountry = 'Australia', Phone = '02 9000 0000');
    a.put('CurrencyIsoCode', cur);
    agencies.put(name, a);
}
upsert agencies.values();
List<Account> enable = new List<Account>();
for (Account a : [SELECT Id, IsPartner FROM Account WHERE Id IN :agencies.values()]) {
    if (!a.IsPartner) enable.add(new Account(Id = a.Id, IsPartner = true));
}
update enable;

// agency => list of [first, last, role]
Map<String, List<List<String>>> people = new Map<String, List<List<String>>>{
    'Harbour & Co Realty' => new List<List<String>>{ new List<String>{ 'Priya', 'Shah', 'Principal' }, new List<String>{ 'Tom', 'Nguyen', 'Agent' }, new List<String>{ 'Ella', 'Brooks', 'Agent' } },
    'Bayside Property Group' => new List<List<String>>{ new List<String>{ 'Marco', 'Rossi', 'Principal' }, new List<String>{ 'Chloe', 'Tan', 'Agent' } },
    'Northside Homes' => new List<List<String>>{ new List<String>{ 'Liam', 'OConnor', 'Agent' } }
};
Set<String> haveContact = new Set<String>();
for (Contact c : [SELECT FirstName, LastName, AccountId FROM Contact WHERE AccountId IN :agencies.values()]) haveContact.add(c.AccountId + c.FirstName + c.LastName);
List<Contact> contacts = new List<Contact>();
for (String agency : people.keySet()) {
    Id accId = agencies.get(agency).Id;
    for (List<String> p : people.get(agency)) {
        if (haveContact.contains(accId + p[0] + p[1])) continue;
        contacts.add(new Contact(AccountId = accId, FirstName = p[0], LastName = p[1], Portal_Role__c = p[2],
            Email = p[0].toLowerCase() + '.' + p[1].toLowerCase() + '@example.com', MobilePhone = '0400 000 000'));
    }
}
insert contacts;
System.debug('PR-DEMO step 2 done: ' + agencies.size() + ' agencies, ' + contacts.size() + ' new agents, price book ' + pb.Id);
