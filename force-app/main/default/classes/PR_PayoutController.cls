/** 002 Partner referral (S07): Finance payout console. */
public with sharing class PR_PayoutController {
    public class BatchView {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String period;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal total;
        @AuraEnabled public Integer runCount;
        @AuraEnabled public Integer lineCount;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getConsole(Id batchId) {
        Map<String, Object> out = new Map<String, Object>();
        out.put('canManage', FeatureManagement.checkPermission(PR_Settings.PERM_MANAGE_PAYOUTS));
        out.put('currentPeriod', PR_PayoutService.defaultPeriod());
        // Summed in Apex: SUM() on a currency field returns the corporate currency (AED), not AUD.
        Integer readyCount = 0;
        Decimal readyTotal = 0;
        for (Partner_Commission__c c : [
            SELECT Amount__c
            FROM Partner_Commission__c
            WHERE Status__c = :PR_Settings.COM_APPROVED AND Payout_Line__c = NULL
            WITH USER_MODE
            LIMIT 10000
        ]) {
            readyCount++;
            readyTotal += c.Amount__c == null ? 0 : c.Amount__c;
        }
        out.put('readyCount', readyCount);
        out.put('readyTotal', readyTotal);
        List<BatchView> batches = new List<BatchView>();
        String soql =
            'SELECT Id, Name, Period_Month__c, Status__c, Total_Ex_GST__c, Run_Count__c, (SELECT Id FROM Lines__r) ' +
            'FROM Payout_Batch__c ' + (batchId == null ? '' : 'WHERE Id = :batchId ') + 'ORDER BY Period_Month__c DESC LIMIT 12';
        for (Payout_Batch__c b : (List<Payout_Batch__c>) Database.queryWithBinds(soql, new Map<String, Object>{ 'batchId' => batchId }, AccessLevel.USER_MODE)) {
            BatchView v = new BatchView();
            v.id = b.Id;
            v.name = b.Name;
            v.period = b.Period_Month__c;
            v.status = b.Status__c;
            v.total = b.Total_Ex_GST__c;
            v.runCount = b.Run_Count__c == null ? 0 : b.Run_Count__c.intValue();
            v.lineCount = b.Lines__r.size();
            batches.add(v);
        }
        out.put('batches', batches);
        return out;
    }

    @AuraEnabled
    public static Id runPayout(String period) {
        try {
            PR_PayoutService.requireFinance();
            return PR_PayoutService.startRun(String.isBlank(period) ? PR_PayoutService.defaultPeriod() : period);
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled
    public static Map<String, String> exportCsv(Id batchId) {
        try {
            String body = PR_PayoutService.export(batchId);
            Payout_Batch__c b = [SELECT Period_Month__c FROM Payout_Batch__c WHERE Id = :batchId WITH USER_MODE];
            return new Map<String, String>{ 'fileName' => 'connectnow-commissions-' + b.Period_Month__c + '.csv', 'body' => body };
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    /** Returns 'Paid' when done, or 'Processing' when a large batch is being marked Paid in the background. */
    @AuraEnabled
    public static String markPaid(Id batchId) {
        try {
            return PR_PayoutService.markPaid(batchId);
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    private static AuraHandledException auraError(Exception e) {
        AuraHandledException a = new AuraHandledException(e.getMessage());
        a.setMessage(e.getMessage());
        return a;
    }
}
