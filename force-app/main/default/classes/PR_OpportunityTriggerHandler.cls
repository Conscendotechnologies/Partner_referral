/**
 * 002 Partner referral (S04, S06): Partner Referral Opportunities only. Keeps the partner-facing status in
 * step, creates the commission on Utilities Connected and handles a reopened won Opportunity.
 * Runs beside the existing OpportunityTrigger, which it does not touch.
 */
public without sharing class PR_OpportunityTriggerHandler {
    public static void afterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Id rt = PR_Settings.opportunityRecordTypeId();
        List<Opportunity> statusChanged = new List<Opportunity>();
        Set<Id> won = new Set<Id>();
        Set<Id> reopened = new Set<Id>();
        for (Opportunity o : newList) {
            if (o.RecordTypeId != rt) continue;
            Opportunity old = oldMap.get(o.Id);
            if (o.StageName != old.StageName || o.OwnerId != old.OwnerId || o.Referral__c != old.Referral__c) {
                statusChanged.add(o);
            }
            if (o.StageName == PR_Settings.STAGE_WON && old.StageName != PR_Settings.STAGE_WON) won.add(o.Id);
            if (old.StageName == PR_Settings.STAGE_WON && o.StageName != PR_Settings.STAGE_WON) reopened.add(o.Id);
        }
        PR_ReferralStatusSync.fromOpportunities(statusChanged);
        PR_CommissionService.handleReopen(reopened);
        PR_CommissionService.createFor(won);
    }
}
