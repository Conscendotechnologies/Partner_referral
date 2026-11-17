/**
 * 002 Partner referral (S07): payout run. Batch scope 200, idempotent (only Approved commissions with no
 * payout line are picked up). Scheduled daily; it only acts on the first business day of the month:
 *   System.schedule('PR monthly payout', '0 0 6 * * ?', new PR_PayoutBatchJob());
 */
public without sharing class PR_PayoutBatchJob implements Database.Batchable<SObject>, Schedulable {
    private Id batchId;

    public PR_PayoutBatchJob() {
    }

    public PR_PayoutBatchJob(Id batchId) {
        this.batchId = batchId;
    }

    public void execute(SchedulableContext sc) {
        Date today = Date.today();
        if (!PR_PayoutService.isFirstBusinessDay(today)) {
            return;
        }
        Payout_Batch__c b = PR_PayoutService.getOrCreateBatch(PR_Settings.periodFor(today));
        if (b.Status__c == PR_Settings.BATCH_DRAFT) {
            Database.executeBatch(new PR_PayoutBatchJob(b.Id), 200);
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return PR_PayoutService.approvedUnbatched();
    }

    public void execute(Database.BatchableContext bc, List<Partner_Commission__c> scope) {
        PR_PayoutService.addToBatch(batchId, scope);
    }

    public void finish(Database.BatchableContext bc) {
        PR_PayoutService.finishRun(batchId);
    }
}
