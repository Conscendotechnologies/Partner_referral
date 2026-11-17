// 002 Partner referral demo, step 4 of 5: sample referrals at every stage, as if agents sent them.
// Uses the same service path as the portal (PR_SystemData.createReferralAndLead), then moves some along:
// contacted, converted, connected (creates commissions), lost. Skips if demo referrals already exist.
if ([SELECT COUNT() FROM Referral__c WHERE Mobile__c LIKE '04129%'] > 0) {
    System.debug('PR-DEMO step 4 skipped: sample referrals exist');
    return;
}
Map<String, User> agents = new Map<String, User>();
for (User u : [SELECT Id, FirstName, LastName, ContactId, Contact.AccountId FROM User WHERE Username LIKE '%@connectnow-partners.demo']) {
    agents.put(u.FirstName, u);
}
// agentFirstName, first, last, street, suburb, state, postcode, moveInDays, utilities
List<List<Object>> rows = new List<List<Object>>{
    new List<Object>{ 'Tom', 'Olivia', 'Harper', '12 Ocean Pde', 'Coogee', 'NSW', '2034', 1, 'Electricity;Gas;Internet' },
    new List<Object>{ 'Tom', 'Noah', 'Williams', '4/88 Crown St', 'Surry Hills', 'NSW', '2010', 9, 'Electricity;Internet' },
    new List<Object>{ 'Tom', 'Mia', 'Chen', '7 Lygon St', 'Carlton', 'VIC', '3053', 21, 'Electricity;Gas;Water' },
    new List<Object>{ 'Priya', 'Jack', 'Patel', '30 Brunswick St', 'Fortitude Valley', 'QLD', '4006', 14, 'Electricity;Internet' },
    new List<Object>{ 'Priya', 'Grace', 'Kelly', '2 Hay St', 'Perth', 'WA', '6000', 30, 'Electricity;Gas' },
    new List<Object>{ 'Chloe', 'Leo', 'Martin', '55 Bay St', 'Brighton', 'VIC', '3186', 2, 'Gas;Internet' },
    new List<Object>{ 'Chloe', 'Zoe', 'Wright', '19 King St', 'Newtown', 'NSW', '2042', 45, 'Electricity;Gas;Water;Internet' },
    new List<Object>{ 'Marco', 'Ethan', 'Brown', '8 Rundle Mall', 'Adelaide', 'SA', '5000', 12, 'Electricity' }
};
Partner_Referral_Setting__mdt s = PR_Settings.get();
List<Referral__c> created = new List<Referral__c>();
Integer n = 0;
for (List<Object> r : rows) {
    User agent = agents.get((String) r[0]);
    if (agent == null) continue;
    n++;
    Referral__c ref = new Referral__c(
        OwnerId = agent.Id, First_Name__c = (String) r[1], Last_Name__c = (String) r[2], Mobile__c = '04129' + String.valueOf(10000 + n).right(5),
        Email__c = ((String) r[1]).toLowerCase() + '@example.com', New_Street__c = (String) r[3], New_Suburb__c = (String) r[4],
        New_State__c = (String) r[5], New_Postcode__c = (String) r[6], Move_In_Date__c = Date.today().addDays((Integer) r[7]),
        Utilities__c = (String) r[8], Referring_Agent__c = agent.ContactId, Referring_Agency__c = agent.Contact.AccountId,
        Consent_Given__c = true, Consent_Given_At__c = System.now(), Consent_Version__c = s.Consent_Version__c,
        Partner_Status__c = 'Received', Is_Urgent__c = PR_Settings.isUrgent(Date.today().addDays((Integer) r[7]))
    );
    ref.put('CurrencyIsoCode', 'AUD');
    PR_SystemData.createReferralAndLead(ref);
    created.add(ref);
}
Id me = UserInfo.getUserId();
// 2 = Noah: contacted. 3 = Mia, 4 = Jack, 6 = Leo: converted (Jack and Leo then connected). 7 = Zoe: lost.
List<Lead> working = new List<Lead>();
for (Integer i : new List<Integer>{ 1, 2, 3, 5, 6 }) {
    if (i < created.size()) working.add(new Lead(Id = created[i].Lead__c, OwnerId = me, Status = 'Working'));
}
update working;
if (created.size() > 6) update new Lead(Id = created[6].Lead__c, Status = 'Unqualified');

List<Database.LeadConvert> converts = new List<Database.LeadConvert>();
for (Integer i : new List<Integer>{ 2, 3, 5 }) {
    if (i >= created.size()) continue;
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(created[i].Lead__c);
    lc.setConvertedStatus('Converted');
    converts.add(lc);
}
List<Id> opps = new List<Id>();
for (Database.LeadConvertResult res : Database.convertLead(converts)) opps.add(res.getOpportunityId());
if (opps.size() >= 3) {
    update new List<Opportunity>{
        new Opportunity(Id = opps[0], StageName = 'Plans Selected'),
        new Opportunity(Id = opps[1], StageName = 'Utilities Connected'),
        new Opportunity(Id = opps[2], StageName = 'Utilities Connected')
    };
    // Partner Manager approves one of the two new commissions.
    List<Partner_Commission__c> pending = [SELECT Id FROM Partner_Commission__c WHERE Opportunity__c = :opps[1] AND Status__c = 'Pending'];
    if (!pending.isEmpty()) update new Partner_Commission__c(Id = pending[0].Id, Status__c = 'Approved');
}
System.debug('PR-DEMO step 4 done: ' + created.size() + ' referrals, ' + opps.size() + ' converted');
