/**
 * 002 Partner referral (S03, AC-03.7): the running rep's Partner Referral queues in one list, urgent movers first,
 * then by move-in date. List view metadata cannot carry a sort order, so this replaces sorting by hand.
 */
public with sharing class PR_QueueLeadsController {
    @TestVisible
    private static Integer rowLimit = 500;
    private static final String PARTNER_QUEUE_PREFIX = 'PR_';

    @AuraEnabled(cacheable=false)
    public static PR_QueueLeadsResult getQueueLeads() {
        PR_QueueLeadsResult result = new PR_QueueLeadsResult();
        result.rowLimit = rowLimit;
        Set<Id> queueIds = partnerQueueIds(UserInfo.getUserId());
        if (queueIds.isEmpty()) {
            return result;
        }
        // One row over the limit tells us whether the list is cut.
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
            LIMIT :(rowLimit + 1)
        ]) {
            if (result.rows.size() == rowLimit) {
                result.hasMore = true;
                break;
            }
            result.rows.add(toRow(l));
        }
        return result;
    }

    /**
     * The PR_ queues the user belongs to, directly or through a public group that is a queue member
     * (one level of group nesting, the way queues are set up in this org).
     */
    private static Set<Id> partnerQueueIds(Id userId) {
        Set<Id> members = new Set<Id>{ userId };
        for (GroupMember m : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :userId AND Group.Type = 'Regular'
            LIMIT 1000
        ]) {
            members.add(m.GroupId);
        }
        Set<Id> queueIds = new Set<Id>();
        // The PR_ prefix is checked in Apex: an escaped underscore in the LIKE pattern ('PR\\_%') reached SOQL as a
        // literal backslash and matched no queue, so every rep saw an empty Referral Queue.
        for (GroupMember m : [
            SELECT GroupId, Group.DeveloperName
            FROM GroupMember
            WHERE UserOrGroupId IN :members AND Group.Type = 'Queue' AND Group.DeveloperName LIKE 'PR%'
            LIMIT 200
        ]) {
            if (m.Group.DeveloperName.startsWith(PARTNER_QUEUE_PREFIX)) {
                queueIds.add(m.GroupId);
            }
        }
        return queueIds;
    }

    private static PR_QueueLeadRow toRow(Lead l) {
        PR_QueueLeadRow r = new PR_QueueLeadRow();
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
        return r;
    }
}
