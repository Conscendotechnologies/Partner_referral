/** 002 Partner referral (S03, AC-03.7): one Lead in the rep's Referral Queue (returned to the prQueueLeads LWC). */
public with sharing class PR_QueueLeadRow {
    @AuraEnabled public Id id;
    @AuraEnabled public String name;
    @AuraEnabled public String queue;
    @AuraEnabled public String state;
    @AuraEnabled public String status;
    @AuraEnabled public Boolean urgent;
    @AuraEnabled public Date moveInDate;
    @AuraEnabled public Datetime firstContactDue;
    @AuraEnabled public Boolean slaBreached;
    @AuraEnabled public String agency;
}
