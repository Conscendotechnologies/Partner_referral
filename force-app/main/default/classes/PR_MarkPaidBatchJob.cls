/**
 * 002 Partner referral (KAN-54, AC-11.1): marks a large payout batch Paid in chunks, so a batch with more
 * commissions than one transaction can update (10,000 DML rows) never fails. Started by
 * PR_PayoutService.markPaid; the batch itself becomes Paid in finish(), only once every commission is Paid.
 */
public without sharing class PR_MarkPaidBatchJob implements Database.Batchable<SObject> {
    private Id batchId;

    public PR_MarkPaidBatchJob(Id batchId) {
        this.batchId = batchId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Partner_Commission__c
            WHERE Payout_Line__r.Payout_Batch__c = :batchId AND Status__c = :PR_Settings.COM_IN_PAYOUT
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Partner_Commission__c> scope) {
        PR_PayoutService.payCommissions(scope);
    }

    public void finish(Database.BatchableContext bc) {
        PR_PayoutService.finishMarkPaid(batchId);
    }
}
