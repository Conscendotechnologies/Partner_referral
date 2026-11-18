/** 002 Partner referral (S03, AC-03.7): the rep's Referral Queue, and whether it was cut at the row limit. */
public with sharing class PR_QueueLeadsResult {
    @AuraEnabled public List<PR_QueueLeadRow> rows = new List<PR_QueueLeadRow>();
    /** True when more open Leads exist than the queue shows (the rows are the first, most urgent ones). */
    @AuraEnabled public Boolean hasMore = false;
    @AuraEnabled public Integer rowLimit;
}
