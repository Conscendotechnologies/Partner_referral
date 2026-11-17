/**
 * 002 Partner referral (S05): after a Partner Referral Lead converts (to a Person Account when no company),
 * the Opportunity gets the Partner Referral record type, first stage, the AUD utilities price book, one
 * product per requested utility, and keeps the referring agency and agent (needed for commission and phase 2).
 */
public without sharing class PR_ConversionHandler {
    public static void handle(List<Lead> converted) {
        Map<Id, Lead> leadByOpp = new Map<Id, Lead>();
        for (Lead l : converted) {
            if (l.ConvertedOpportunityId != null) leadByOpp.put(l.ConvertedOpportunityId, l);
        }
        if (leadByOpp.isEmpty()) {
            return;
        }
        String cur = PR_Settings.currencyCode();
        Map<String, Id> entryByProduct = new Map<String, Id>();
        Map<String, Decimal> priceByProduct = new Map<String, Decimal>();
        Id pricebookId;
        for (PricebookEntry pbe : (List<PricebookEntry>) Database.queryWithBinds(
            'SELECT Id, Pricebook2Id, Product2.Name, UnitPrice FROM PricebookEntry ' +
            'WHERE Pricebook2.Name = :pb AND Pricebook2.IsActive = true AND IsActive = true AND CurrencyIsoCode = :cur',
            new Map<String, Object>{ 'pb' => PR_Settings.get().Price_Book_Name__c, 'cur' => cur },
            AccessLevel.SYSTEM_MODE
        )) {
            pricebookId = pbe.Pricebook2Id;
            entryByProduct.put(pbe.Product2.Name, pbe.Id);
            priceByProduct.put(pbe.Product2.Name, pbe.UnitPrice);
        }

        Id rt = PR_Settings.opportunityRecordTypeId();
        List<Opportunity> opps = new List<Opportunity>();
        for (Opportunity o : [SELECT Id, Pricebook2Id, (SELECT Id FROM OpportunityLineItems) FROM Opportunity WHERE Id IN :leadByOpp.keySet()]) {
            Lead l = leadByOpp.get(o.Id);
            Opportunity upd = new Opportunity(
                Id = o.Id,
                RecordTypeId = rt,
                StageName = PR_Settings.STAGE_FIRST,
                Referral__c = l.Referral__c,
                Referring_Agency__c = l.Referring_Agency__c,
                Referring_Agent__c = l.Referring_Agent__c,
                Move_In_Date__c = l.Move_In_Date__c
            );
            if (o.OpportunityLineItems.isEmpty()) {
                upd.put('CurrencyIsoCode', cur);
                if (pricebookId != null) upd.Pricebook2Id = pricebookId;
            }
            opps.add(upd);
        }
        update opps;

        List<OpportunityLineItem> lines = new List<OpportunityLineItem>();
        List<Referral__c> referrals = new List<Referral__c>();
        for (Opportunity o : opps) {
            Lead l = leadByOpp.get(o.Id);
            if (o.Pricebook2Id != null && l.Utilities__c != null) {
                for (String utility : l.Utilities__c.split(';')) {
                    if (!entryByProduct.containsKey(utility)) continue;
                    lines.add(new OpportunityLineItem(
                        OpportunityId = o.Id,
                        PricebookEntryId = entryByProduct.get(utility),
                        Quantity = 1,
                        UnitPrice = priceByProduct.get(utility)
                    ));
                }
            }
            if (l.Referral__c != null) {
                referrals.add(new Referral__c(Id = l.Referral__c, Opportunity__c = o.Id, Partner_Status__c = PR_Settings.REF_IN_PROGRESS));
            }
        }
        insert lines;
        update referrals;
    }
}
