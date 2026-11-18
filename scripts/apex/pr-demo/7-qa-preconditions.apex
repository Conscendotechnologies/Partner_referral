// 002 Partner referral QA: preconditions for the S05 and S06 suites (and S12-TC-02).
// Creates, through the same service path as the portal, two AI-TEST referrals from Tom Nguyen (Harbour & Co Realty):
//  - "AI-TEST Convert QA": Lead, NSW, Electricity + Internet, owned by Sam Rep (PR test), status Working (S05-TC-01).
//  - "AI-TEST Commission QA": converted, 3 products, Opportunity owned by Sam Rep at Connection Requested (S06-TC-02).
// Run after 1-6. Skips each record that already exists, so it is safe to re-run.
User tom = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE FirstName = 'Tom' AND Username LIKE '%@connectnow-partners.demo' AND IsActive = TRUE LIMIT 1];
User sam = [SELECT Id FROM User WHERE Name = 'Sam Rep (PR test)' AND IsActive = TRUE LIMIT 1];
Partner_Referral_Setting__mdt s = PR_Settings.get();

Referral__c newReferral(String last, String mobile, String utilities) {
    Date moveIn = Date.today().addDays(20);
    Referral__c ref = new Referral__c(
        OwnerId = tom.Id, First_Name__c = 'AI-TEST', Last_Name__c = last, Mobile__c = mobile,
        New_Street__c = '1 AI-TEST Street', New_Suburb__c = 'Parramatta', New_State__c = 'NSW', New_Postcode__c = '2150',
        Move_In_Date__c = moveIn, Utilities__c = utilities, Referring_Agent__c = tom.ContactId,
        Referring_Agency__c = tom.Contact.AccountId, Consent_Given__c = true, Consent_Given_At__c = System.now(),
        Consent_Version__c = s.Consent_Version__c, Partner_Status__c = 'Received', Is_Urgent__c = PR_Settings.isUrgent(moveIn)
    );
    ref.put('CurrencyIsoCode', 'AUD');
    PR_SystemData.createReferralAndLead(ref);
    return ref;
}

if ([SELECT COUNT() FROM Lead WHERE LastName = 'Convert QA' AND FirstName = 'AI-TEST' AND IsConverted = FALSE] == 0) {
    Referral__c ref = newReferral('Convert QA', '0412000901', 'Electricity;Internet');
    update new Lead(Id = ref.Lead__c, OwnerId = sam.Id, Status = 'Working');
    System.debug('PR-QA: created AI-TEST Convert QA lead ' + ref.Lead__c);
}

if ([SELECT COUNT() FROM Opportunity WHERE Name = 'AI-TEST Commission QA'] == 0) {
    Referral__c ref = newReferral('Commission QA', '0412000902', 'Electricity;Gas;Internet');
    // The admin owns the Lead while it converts: a Lead owned by Sam Rep (Standard User) fails conversion with
    // UNAVAILABLE_RECORDTYPE_EXCEPTION (QA defect, S05). The Opportunity is handed to Sam afterwards.
    update new Lead(Id = ref.Lead__c, OwnerId = UserInfo.getUserId(), Status = 'Working');
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(ref.Lead__c);
    lc.setConvertedStatus('Converted');
    Id oppId = Database.convertLead(lc).getOpportunityId();
    update new Opportunity(Id = oppId, OwnerId = sam.Id, Name = 'AI-TEST Commission QA', StageName = 'Connection Requested');
    System.debug('PR-QA: created AI-TEST Commission QA opportunity ' + oppId);
}
