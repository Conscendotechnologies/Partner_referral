// 002 Partner referral QA, reset part 1 of 2 (referrals): closes (Partner Status "Closed Lost") the open AI-TEST
// referrals that earlier runs left behind, so the S02 suite's fixed mobiles don't raise a duplicate warning on the
// next run. The S05/S06/S07 fixture referrals ("Convert QA", "Commission QA", "Pending QA", "Payout QA") are kept. AI-TEST data only.
// CI runs it through automation-testing/scripts/qa-data.mjs, before 9-qa-reset-commissions.apex and 7-qa-preconditions.apex.
Set<String> fixtureLastNames = new Set<String>{ 'Convert QA', 'Commission QA', 'Pending QA', 'Payout QA' };
// --- 1. S02 referrals.
List<Referral__c> stale = [
    SELECT Id FROM Referral__c
    WHERE (First_Name__c LIKE 'AI-TEST%' OR Last_Name__c LIKE 'AI-TEST%') AND Last_Name__c NOT IN :fixtureLastNames
        AND Partner_Status__c NOT IN (:PR_Settings.REF_CONNECTED, :PR_Settings.REF_CLOSED_LOST)
];
for (Referral__c r : stale) r.Partner_Status__c = PR_Settings.REF_CLOSED_LOST;
update stale;
System.debug('PR-QA reset: closed ' + stale.size() + ' AI-TEST referrals');
