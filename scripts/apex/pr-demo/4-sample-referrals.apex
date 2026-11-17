// 002 Partner referral demo, step 4 of 6: sample referrals at every stage, as if agents sent them.
// Uses the same service path as the portal (PR_SystemData.createReferralAndLead), then moves some along:
// contacted, converted, connected (creates commissions), lost. Skips if demo referrals already exist.
if ([SELECT COUNT() FROM Referral__c WHERE Mobile__c LIKE '04129%'] > 0) {
    System.debug('PR-DEMO step 4 skipped: sample referrals exist');
    return;
}

// agentFirstName, mover first, last, street, suburb, state, postcode, moveInDays, utilities
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
// What happens to each sample after it is sent, by mover first name.
Set<String> contacted = new Set<String>{ 'Noah', 'Mia', 'Jack', 'Leo', 'Zoe' };
Set<String> lost = new Set<String>{ 'Zoe' };
Map<String, String> convertTo = new Map<String, String>{
    'Mia' => 'Plans Selected',
    'Jack' => 'Utilities Connected',
    'Leo' => 'Utilities Connected'
};
String approve = 'Jack';

// Every demo agent must exist before anything is created, so a partial run can't leave half a demo behind.
Map<String, User> agents = new Map<String, User>();
for (User u : [SELECT Id, FirstName, LastName, ContactId, Contact.AccountId FROM User WHERE Username LIKE '%@connectnow-partners.demo' AND IsActive = TRUE]) {
    agents.put(u.FirstName, u);
}
List<String> missing = new List<String>();
for (List<Object> r : rows) {
    String agent = (String) r[0];
    if (!agents.containsKey(agent) && !missing.contains(agent)) missing.add(agent);
}
if (!missing.isEmpty()) {
    throw new IllegalArgumentException('Demo agents missing, nothing created: ' + String.join(missing, ', ') + '. Run 3-portal-users.apex first.');
}

Partner_Referral_Setting__mdt s = PR_Settings.get();
Map<String, Referral__c> byMover = new Map<String, Referral__c>();
Integer n = 0;
for (List<Object> r : rows) {
    User agent = agents.get((String) r[0]);
    n++;
    Date moveIn = Date.today().addDays((Integer) r[7]);
    Referral__c ref = new Referral__c(
        OwnerId = agent.Id, First_Name__c = (String) r[1], Last_Name__c = (String) r[2], Mobile__c = '04129' + String.valueOf(10000 + n).right(5),
        Email__c = ((String) r[1]).toLowerCase() + '@example.com', New_Street__c = (String) r[3], New_Suburb__c = (String) r[4],
        New_State__c = (String) r[5], New_Postcode__c = (String) r[6], Move_In_Date__c = moveIn,
        Utilities__c = (String) r[8], Referring_Agent__c = agent.ContactId, Referring_Agency__c = agent.Contact.AccountId,
        Consent_Given__c = true, Consent_Given_At__c = System.now(), Consent_Version__c = s.Consent_Version__c,
        Partner_Status__c = 'Received', Is_Urgent__c = PR_Settings.isUrgent(moveIn)
    );
    ref.put('CurrencyIsoCode', 'AUD');
    PR_SystemData.createReferralAndLead(ref);
    byMover.put((String) r[1], ref);
}

Id me = UserInfo.getUserId();
List<Lead> working = new List<Lead>();
for (String mover : contacted) working.add(new Lead(Id = byMover.get(mover).Lead__c, OwnerId = me, Status = 'Working'));
update working;
List<Lead> unqualified = new List<Lead>();
for (String mover : lost) unqualified.add(new Lead(Id = byMover.get(mover).Lead__c, Status = 'Unqualified'));
update unqualified;

List<String> converting = new List<String>(convertTo.keySet());
List<Database.LeadConvert> converts = new List<Database.LeadConvert>();
for (String mover : converting) {
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(byMover.get(mover).Lead__c);
    lc.setConvertedStatus('Converted');
    converts.add(lc);
}
Map<String, Id> oppByMover = new Map<String, Id>();
List<Database.LeadConvertResult> results = Database.convertLead(converts);
for (Integer i = 0; i < results.size(); i++) oppByMover.put(converting[i], results[i].getOpportunityId());

List<Opportunity> stages = new List<Opportunity>();
for (String mover : converting) stages.add(new Opportunity(Id = oppByMover.get(mover), StageName = convertTo.get(mover)));
update stages;

// The Partner Manager approves one of the new commissions.
List<Partner_Commission__c> pending = [SELECT Id FROM Partner_Commission__c WHERE Opportunity__c = :oppByMover.get(approve) AND Status__c = 'Pending'];
if (!pending.isEmpty()) update new Partner_Commission__c(Id = pending[0].Id, Status__c = 'Approved');
System.debug('PR-DEMO step 4 done: ' + byMover.size() + ' referrals, ' + oppByMover.size() + ' converted');
