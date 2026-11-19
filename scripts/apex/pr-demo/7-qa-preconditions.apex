// 002 Partner referral QA: preconditions for the S05 and S06 suites (and S12-TC-02).
// Creates, through the same service path as the portal, two AI-TEST referrals from Tom Nguyen (Harbour & Co Realty):
//  - "AI-TEST Convert QA": Lead, NSW, Electricity + Internet, owned by Sam Rep (PR test), status Working (S05-TC-01).
//  - "AI-TEST Commission QA": converted, 3 products, Opportunity owned by Sam Rep at Connection Requested (S06-TC-02).
//  - "AI-TEST Commission Pending QA": converted and at Utilities Connected, with exactly one Pending commission
//    (S06-TC-11, which must not depend on what S06-TC-10 does to the S06-TC-02 commission).
//  - "AI-TEST Payout QA": converted and at Utilities Connected, with its commission Approved and not yet in a batch
//    (S07-TC-03), so the payout cases don't depend on S06-TC-10.
// Run after 1-6, and after 9-qa-reset-commissions.apex, which retires fixtures that an earlier run moved on. Skips each record
// that already exists in its starting state, and stops if one exists in any other state.
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

// The admin owns the Lead while it converts: a Lead owned by Sam Rep (Standard User) failed conversion with
// UNAVAILABLE_RECORDTYPE_EXCEPTION before the fix in PR 8 (D1). The Opportunity is handed to Sam afterwards.
Id convertedOpportunity(String last, String mobile, String name) {
    Referral__c ref = newReferral(last, mobile, 'Electricity;Gas;Internet');
    update new Lead(Id = ref.Lead__c, OwnerId = UserInfo.getUserId(), Status = 'Working');
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(ref.Lead__c);
    lc.setConvertedStatus('Converted');
    Id oppId = Database.convertLead(lc).getOpportunityId();
    update new Opportunity(Id = oppId, OwnerId = sam.Id, Name = name, StageName = 'Connection Requested');
    return oppId;
}

List<Opportunity> commissionQa = [
    SELECT Id, StageName, (SELECT Id FROM OpportunityLineItems) FROM Opportunity WHERE Name = 'AI-TEST Commission QA'
];
if (commissionQa.isEmpty()) {
    Id oppId = convertedOpportunity('Commission QA', '0412000902', 'AI-TEST Commission QA');
    System.debug('PR-QA: created AI-TEST Commission QA opportunity ' + oppId);
} else {
    Opportunity o = commissionQa[0];
    Integer commissions = [SELECT COUNT() FROM Partner_Commission__c WHERE Opportunity__c = :o.Id];
    if (commissionQa.size() > 1 || o.StageName != 'Connection Requested' || commissions > 0 || o.OpportunityLineItems.size() != 3) {
        throw new PR_Exception('"AI-TEST Commission QA" is not in its starting state (Connection Requested, 3 products, '
            + 'no commission). Run scripts/apex/pr-demo/9-qa-reset-commissions.apex first.');
    }
}

List<Opportunity> pendingQa = [SELECT Id FROM Opportunity WHERE Name = 'AI-TEST Commission Pending QA'];
if (pendingQa.isEmpty()) {
    Id oppId = convertedOpportunity('Pending QA', '0412000904', 'AI-TEST Commission Pending QA');
    update new Opportunity(Id = oppId, StageName = PR_Settings.STAGE_WON);
    Integer pending = [SELECT COUNT() FROM Partner_Commission__c WHERE Opportunity__c = :oppId AND Status__c = :PR_Settings.COM_PENDING];
    if (pending != 1) {
        throw new PR_Exception('Expected one Pending commission on AI-TEST Commission Pending QA, found ' + pending + '.');
    }
    System.debug('PR-QA: created AI-TEST Commission Pending QA opportunity ' + oppId);
} else if (pendingQa.size() > 1
        || [SELECT COUNT() FROM Partner_Commission__c WHERE Opportunity__c = :pendingQa[0].Id] != 1
        || [SELECT COUNT() FROM Partner_Commission__c WHERE Opportunity__c = :pendingQa[0].Id AND Status__c = :PR_Settings.COM_PENDING] != 1) {
    throw new PR_Exception('"AI-TEST Commission Pending QA" does not have exactly one Pending commission. '
        + 'Run scripts/apex/pr-demo/9-qa-reset-commissions.apex first.');
}

// The S07 fixture is seeded only when S07 can run, by the same rule as 9-qa-reset-commissions.apex: no Approved
// commission that is not AI-TEST waits for a payout, and the default period has no batch (9 removed an AI-TEST one).
// Otherwise it prints "PR-QA S07: SKIP" (qa-data.mjs then sets SF_SKIP_S07=1) and creates nothing for S07.
Boolean s07Ready = [
        SELECT COUNT() FROM Partner_Commission__c
        WHERE Status__c = :PR_Settings.COM_APPROVED AND Payout_Line__c = NULL AND (NOT Opportunity__r.Name LIKE 'AI-TEST%')
    ] == 0
    && [SELECT COUNT() FROM Payout_Batch__c WHERE Period_Month__c = :PR_PayoutService.defaultPeriod()] == 0;
if (!s07Ready) {
    System.debug('PR-QA S07: SKIP the payout data is not AI-TEST alone, so the AI-TEST Payout QA fixture is not seeded');
} else if ([SELECT COUNT() FROM Partner_Commission__c WHERE Opportunity__r.Name = 'AI-TEST Payout QA'
        AND Status__c = :PR_Settings.COM_APPROVED AND Payout_Line__c = NULL] == 0) {
    if ([SELECT COUNT() FROM Opportunity WHERE Name = 'AI-TEST Payout QA'] > 0) {
        throw new PR_Exception('"AI-TEST Payout QA" has no Approved commission waiting for a payout. '
            + 'Run scripts/apex/pr-demo/9-qa-reset-commissions.apex first.');
    }
    Id oppId = convertedOpportunity('Payout QA', '0412000903', 'AI-TEST Payout QA');
    update new Opportunity(Id = oppId, StageName = PR_Settings.STAGE_WON);
    List<Partner_Commission__c> created = [SELECT Id FROM Partner_Commission__c WHERE Opportunity__c = :oppId];
    if (created.size() != 1) {
        throw new PR_Exception('Expected one commission on AI-TEST Payout QA, found ' + created.size() + '.');
    }
    created[0].Status__c = PR_Settings.COM_APPROVED;
    created[0].Approved_By__c = UserInfo.getUserId();
    created[0].Approved_On__c = System.now();
    PR_CommissionService.withBypass(created, false);
    System.debug('PR-QA: created AI-TEST Payout QA opportunity ' + oppId + ' with Approved commission ' + created[0].Id);
}
