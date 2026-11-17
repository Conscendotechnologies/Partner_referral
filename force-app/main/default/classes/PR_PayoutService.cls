/**
 * 002 Partner referral (S07): monthly payout.
 * All Approved commissions not yet in a batch are grouped into one line per agency and moved to
 * Included in Payout. Re-running the same day only picks up newly approved ones, so a commission can never
 * appear twice. Once Exported (CSV downloaded) the batch is closed; late approvals go to next month.
 */
public without sharing class PR_PayoutService {
    public static final String CSV_HEADER = 'Agency Name,ABN,Payment Reference,Total Ex GST,Commission Count,Month';

    public static void requireFinance() {
        if (!FeatureManagement.checkPermission(PR_Settings.PERM_MANAGE_PAYOUTS)) {
            throw new PR_Exception('Only Finance can run, export or pay commission batches.');
        }
    }

    /** First Monday-to-Friday of the month. */
    public static Boolean isFirstBusinessDay(Date d) {
        Date x = d.toStartOfMonth();
        while (isWeekend(x)) x = x.addDays(1);
        return x == d;
    }

    private static Boolean isWeekend(Date d) {
        String day = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('EEE');
        return day == 'Sat' || day == 'Sun';
    }

    public static Payout_Batch__c getOrCreateBatch(String period) {
        List<Payout_Batch__c> existing = [
            SELECT Id, Name, Status__c, Period_Month__c, Run_Count__c
            FROM Payout_Batch__c
            WHERE Period_Month__c = :period
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        Payout_Batch__c b = new Payout_Batch__c(Name = 'Commission payout ' + period, Period_Month__c = period, Status__c = PR_Settings.BATCH_DRAFT, Run_Count__c = 0);
        b.put('CurrencyIsoCode', PR_Settings.currencyCode());
        insert b;
        return b;
    }

    /** Starts (or re-runs) the payout for a month. Returns the batch Id. */
    public static Id startRun(String period) {
        Payout_Batch__c b = getOrCreateBatch(period);
        if (b.Status__c != PR_Settings.BATCH_DRAFT) {
            throw new PR_Exception('The ' + period + ' payout is already ' + b.Status__c + '. New approvals go into next month.');
        }
        Database.executeBatch(new PR_PayoutBatchJob(b.Id), 200);
        return b.Id;
    }

    public static Database.QueryLocator approvedUnbatched() {
        return Database.getQueryLocator([
            SELECT Id, Agency__c, Amount__c
            FROM Partner_Commission__c
            WHERE Status__c = :PR_Settings.COM_APPROVED AND Payout_Line__c = NULL
            ORDER BY Agency__c
        ]);
    }

    /** Adds one chunk of approved commissions to the batch, accumulating per-agency lines. */
    public static void addToBatch(Id batchId, List<Partner_Commission__c> scope) {
        Payout_Batch__c b = [SELECT Id, Period_Month__c, Status__c FROM Payout_Batch__c WHERE Id = :batchId];
        if (b.Status__c != PR_Settings.BATCH_DRAFT) {
            return;
        }
        Map<Id, List<Partner_Commission__c>> byAgency = new Map<Id, List<Partner_Commission__c>>();
        for (Partner_Commission__c c : [
            SELECT Id, Agency__c, Amount__c
            FROM Partner_Commission__c
            WHERE Id IN :scope AND Status__c = :PR_Settings.COM_APPROVED AND Payout_Line__c = NULL AND Agency__c != NULL
        ]) {
            if (!byAgency.containsKey(c.Agency__c)) byAgency.put(c.Agency__c, new List<Partner_Commission__c>());
            byAgency.get(c.Agency__c).add(c);
        }
        if (byAgency.isEmpty()) {
            return;
        }
        Map<Id, Account> agencies = new Map<Id, Account>([SELECT Id, Name, ABN__c FROM Account WHERE Id IN :byAgency.keySet()]);
        Map<String, Payout_Line__c> existing = new Map<String, Payout_Line__c>();
        for (Payout_Line__c l : [
            SELECT Id, Line_Key__c, Total_Ex_GST__c, Commission_Count__c
            FROM Payout_Line__c
            WHERE Payout_Batch__c = :batchId AND Agency__c IN :byAgency.keySet()
        ]) {
            existing.put(l.Line_Key__c, l);
        }
        String ym = b.Period_Month__c.replace('-', '');
        Map<Id, Payout_Line__c> lineByAgency = new Map<Id, Payout_Line__c>();
        for (Id agencyId : byAgency.keySet()) {
            Account a = agencies.get(agencyId);
            String key = String.valueOf(batchId) + String.valueOf(agencyId);
            Payout_Line__c line = existing.containsKey(key)
                ? existing.get(key)
                : new Payout_Line__c(Payout_Batch__c = batchId, Agency__c = agencyId, Line_Key__c = key, Total_Ex_GST__c = 0, Commission_Count__c = 0);
            line.Name = a.Name.left(80);
            line.ABN__c = a.ABN__c;
            line.Payment_Reference__c = ym + '-' + (a.ABN__c == null ? 'NOABN' : a.ABN__c);
            for (Partner_Commission__c c : byAgency.get(agencyId)) {
                line.Total_Ex_GST__c += c.Amount__c == null ? 0 : c.Amount__c;
                line.Commission_Count__c += 1;
            }
            if (line.Id == null) line.put('CurrencyIsoCode', PR_Settings.currencyCode());
            lineByAgency.put(agencyId, line);
        }
        upsert lineByAgency.values() Line_Key__c;

        List<Partner_Commission__c> updates = new List<Partner_Commission__c>();
        for (Id agencyId : byAgency.keySet()) {
            for (Partner_Commission__c c : byAgency.get(agencyId)) {
                updates.add(new Partner_Commission__c(Id = c.Id, Payout_Line__c = lineByAgency.get(agencyId).Id, Status__c = PR_Settings.COM_IN_PAYOUT));
            }
        }
        PR_CommissionService.withBypass(updates, false);
    }

    public static void finishRun(Id batchId) {
        Payout_Batch__c b = [SELECT Id, Run_Count__c FROM Payout_Batch__c WHERE Id = :batchId];
        b.Run_Count__c = (b.Run_Count__c == null ? 0 : b.Run_Count__c) + 1;
        update b;
    }

    /** Xero CSV: agency name, ABN, payment reference (YYYYMM-ABN), total ex GST, commission count, month. */
    public static String buildCsv(Id batchId) {
        Payout_Batch__c b = [SELECT Id, Period_Month__c FROM Payout_Batch__c WHERE Id = :batchId];
        List<String> rows = new List<String>{ CSV_HEADER };
        for (Payout_Line__c l : [
            SELECT Agency__r.Name, ABN__c, Payment_Reference__c, Total_Ex_GST__c, Commission_Count__c
            FROM Payout_Line__c
            WHERE Payout_Batch__c = :batchId
            ORDER BY Agency__r.Name
        ]) {
            rows.add(String.join(new List<String>{
                csv(l.Agency__r.Name),
                csv(l.ABN__c),
                csv(l.Payment_Reference__c),
                String.valueOf(l.Total_Ex_GST__c.setScale(2)),
                String.valueOf(l.Commission_Count__c.intValue()),
                csv(b.Period_Month__c)
            }, ','));
        }
        return String.join(rows, '\n') + '\n';
    }

    private static String csv(String v) {
        if (v == null) return '';
        return v.containsAny(',"\n') ? '"' + v.replace('"', '""') + '"' : v;
    }

    public static String export(Id batchId) {
        requireFinance();
        String body = buildCsv(batchId);
        Payout_Batch__c b = [SELECT Id, Status__c FROM Payout_Batch__c WHERE Id = :batchId];
        if (b.Status__c == PR_Settings.BATCH_DRAFT) {
            update new Payout_Batch__c(Id = batchId, Status__c = PR_Settings.BATCH_EXPORTED);
        }
        return body;
    }

    /** Marks the batch Paid and every commission in it Paid. */
    public static void markPaid(Id batchId) {
        requireFinance();
        Payout_Batch__c b = [SELECT Id, Status__c FROM Payout_Batch__c WHERE Id = :batchId];
        if (b.Status__c == PR_Settings.BATCH_PAID) {
            return;
        }
        if (b.Status__c != PR_Settings.BATCH_EXPORTED) {
            throw new PR_Exception('Download the Xero CSV before marking the batch Paid.');
        }
        List<Partner_Commission__c> updates = new List<Partner_Commission__c>();
        for (Partner_Commission__c c : [
            SELECT Id
            FROM Partner_Commission__c
            WHERE Payout_Line__r.Payout_Batch__c = :batchId AND Status__c = :PR_Settings.COM_IN_PAYOUT
        ]) {
            updates.add(new Partner_Commission__c(Id = c.Id, Status__c = PR_Settings.COM_PAID));
        }
        PR_CommissionService.withBypass(updates, false);
        update new Payout_Batch__c(Id = batchId, Status__c = PR_Settings.BATCH_PAID, Paid_On__c = Date.today());
    }
}
