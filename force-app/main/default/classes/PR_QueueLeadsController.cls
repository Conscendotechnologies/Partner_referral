/**
 * 002 Partner referral (S03, AC-03.7): the running rep's Partner Referral queues in one list, urgent movers first,
 * then by move-in date. List view metadata cannot carry a sort order, so this replaces sorting by hand.
 */
public with sharing class PR_QueueLeadsController {
    public class LeadRow {
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

    @AuraEnabled(cacheable=false)
    public static List<LeadRow> getQueueLeads() {
        Set<Id> queueIds = new Set<Id>();
        for (GroupMember m : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :UserInfo.getUserId() AND Group.Type = 'Queue' AND Group.DeveloperName LIKE 'PR\\_%'
        ]) {
            queueIds.add(m.GroupId);
        }
        List<LeadRow> rows = new List<LeadRow>();
        if (queueIds.isEmpty()) {
            return rows;
        }
        for (Lead l : [
            SELECT Id, Name, Owner.Name, State, Status, Is_Urgent__c, Move_In_Date__c, SLA_Due_At__c, SLA_Breached__c,
                Referring_Agency__r.Name
            FROM Lead
            WHERE RecordType.DeveloperName = :PR_Settings.RT_DEV_NAME
                AND OwnerId IN :queueIds
                AND IsConverted = FALSE
                AND Status != :PR_Settings.LEAD_UNQUALIFIED
            WITH USER_MODE
            ORDER BY Is_Urgent__c DESC, Move_In_Date__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 500
        ]) {
            LeadRow r = new LeadRow();
            r.id = l.Id;
            r.name = l.Name;
            r.queue = l.Owner.Name;
            r.state = l.State;
            r.status = l.Status;
            r.urgent = l.Is_Urgent__c;
            r.moveInDate = l.Move_In_Date__c;
            r.firstContactDue = l.SLA_Due_At__c;
            r.slaBreached = l.SLA_Breached__c;
            r.agency = l.Referring_Agency__r?.Name;
            rows.add(r);
        }
        return rows;
    }
}
