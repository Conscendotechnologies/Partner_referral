// 002 Partner referral QA, reset part 2 of 2 (commissions and payouts). AI-TEST data only.
//  - S06: retires "AI-TEST Commission QA" when an earlier run moved it on (stage is no longer Connection Requested,
//    it has a commission, or it no longer has 3 products). It is renamed "AI-TEST Retired QA <time>" and its open
//    commissions are cancelled, so 7-qa-preconditions.apex creates a fresh one.
//  - S05: retires any Opportunity an earlier S05-TC-01 run converted from "AI-TEST Convert QA" (named
//    "AI-TEST Convert…"), so S05-TC-02/04 find only this run's conversion.
//  - S07: removes the default payout period's batch when it holds commissions and every one of them is AI-TEST (its
//    commissions are cancelled, its lines and the batch deleted, whatever its status: S07-TC-09 leaves it Paid). It
//    retires "AI-TEST Payout QA" and cancels its unbatched commission, so a fresh one is seeded when S07 runs and no
//    Approved AI-TEST commission waits for a real payout run when it does not. When the payout data is not shown to be
//    AI-TEST alone it prints "PR-QA S07: SKIP" and leaves every batch, line and batched commission as it is.
// CI runs it through automation-testing/scripts/qa-data.mjs, after 8-qa-reset-referrals.apex and before
// 7-qa-preconditions.apex.
String stamp = System.now().format('yyyyMMdd-HHmmss');
Set<String> openCommission = new Set<String>{ PR_Settings.COM_PENDING, PR_Settings.COM_APPROVED, PR_Settings.COM_IN_PAYOUT };

// --- Guard (S07): the payout run takes every Approved, unbatched commission in the org, and the period's batch can be
// built only once. S07 runs only when both involve AI-TEST data alone; otherwise this script prints
// "PR-QA S07: SKIP <reason>" (CI then leaves the S07 specs out) and changes no payout data.
String s07Skip = null;
List<Partner_Commission__c> foreign = [
    SELECT Name, Opportunity__r.Name FROM Partner_Commission__c
    WHERE Status__c = :PR_Settings.COM_APPROVED AND Payout_Line__c = NULL AND (NOT Opportunity__r.Name LIKE 'AI-TEST%')
    LIMIT 5
];
if (!foreign.isEmpty()) {
    s07Skip = 'Approved commissions that are not AI-TEST are waiting for a payout, and a payout run would include them';
}
String period = PR_PayoutService.defaultPeriod();
List<Payout_Batch__c> batches = [SELECT Id, Status__c FROM Payout_Batch__c WHERE Period_Month__c = :period];
List<Partner_Commission__c> batched = batches.isEmpty() ? new List<Partner_Commission__c>() : [
    SELECT Id, Opportunity__r.Name FROM Partner_Commission__c WHERE Payout_Line__r.Payout_Batch__c IN :batches
];
// A batch is removed only on positive evidence: it holds commissions and all of them are AI-TEST.
if (s07Skip == null && !batches.isEmpty() && batched.isEmpty()) {
    s07Skip = 'the ' + period + ' payout batch holds no commissions, so nothing shows it is AI-TEST data; it is left as it is';
}
for (Partner_Commission__c c : batched) {
    if (s07Skip == null && (c.Opportunity__r == null || !c.Opportunity__r.Name.startsWith('AI-TEST'))) {
        s07Skip = 'the ' + period + ' payout batch holds commissions that are not AI-TEST, so it is left as it is';
    }
}
if (s07Skip != null) {
    batches = new List<Payout_Batch__c>();
    batched = new List<Partner_Commission__c>();
    System.debug('PR-QA S07: SKIP ' + s07Skip);
} else {
    System.debug('PR-QA S07: READY');
}

// --- 2 and 3. Retire used fixtures and clear this period's AI-TEST batch.
List<Opportunity> retire = new List<Opportunity>();
for (Opportunity o : [
    SELECT Id, Name, StageName, (SELECT Id FROM OpportunityLineItems)
    FROM Opportunity WHERE Name IN ('AI-TEST Commission QA', 'AI-TEST Payout QA') OR Name LIKE 'AI-TEST Convert%'
]) {
    Integer commissions = [SELECT COUNT() FROM Partner_Commission__c WHERE Opportunity__c = :o.Id];
    Boolean used = o.Name == 'AI-TEST Payout QA' || o.Name.startsWith('AI-TEST Convert')
        || o.StageName != 'Connection Requested' || commissions > 0 || o.OpportunityLineItems.size() != 3;
    if (used) retire.add(new Opportunity(Id = o.Id, Name = 'AI-TEST Retired QA ' + stamp));
}

List<Partner_Commission__c> cancel = new List<Partner_Commission__c>();
Set<Id> retireIds = new Map<Id, Opportunity>(retire).keySet();
for (Partner_Commission__c c : [
    SELECT Id, Status__c, Payout_Line__c FROM Partner_Commission__c
    WHERE Opportunity__c IN :retireIds OR Id IN :batched
]) {
    if (!openCommission.contains(c.Status__c) && c.Payout_Line__c == null) continue;
    // SKIP leaves payout data alone: a batched commission keeps its status and its line.
    if (s07Skip != null && c.Payout_Line__c != null) continue;
    c.Status__c = PR_Settings.COM_CANCELLED;
    c.Cancellation_Reason__c = 'QA reset ' + stamp;
    c.Opportunity_Key__c = null;
    c.Payout_Line__c = null;
    cancel.add(c);
}
PR_CommissionService.withBypass(cancel, false);
update retire;
if (!batches.isEmpty()) {
    delete [SELECT Id FROM Payout_Line__c WHERE Payout_Batch__c IN :batches];
    delete batches;
}
System.debug('PR-QA reset: retired ' + retire.size() + ' opportunities, cancelled '
    + cancel.size() + ' commissions, removed ' + batches.size() + ' payout batch(es) for ' + period);
