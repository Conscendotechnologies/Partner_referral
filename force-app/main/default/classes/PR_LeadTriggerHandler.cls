/**
 * 002 Partner referral (S03, S04, S05): Partner Referral Leads only.
 * - Urgent = move-in within 48 h, recalculated every save (both ways).
 * - SLA due = 2 business hours from creation; first move to Working stamps First Contacted At.
 * - Notifies the queue when a lead becomes urgent; keeps the partner-facing Referral status in step;
 *   finishes conversion (record type, price book, one product per utility).
 */
public without sharing class PR_LeadTriggerHandler {
    private static List<Lead> partnerLeads(List<Lead> leads) {
        Id rt = PR_Settings.leadRecordTypeId();
        List<Lead> out = new List<Lead>();
        for (Lead l : leads) {
            if (l.RecordTypeId == rt) out.add(l);
        }
        return out;
    }

    public static void beforeInsert(List<Lead> newList) {
        Datetime now = System.now();
        // AC-03.1: every new Partner Referral Lead is routed by state, however it is created (portal, API, data
        // load or by hand), as the assignment rule in the design would. A Lead already owned by a PR queue keeps it.
        Set<Id> prQueues = new Set<Id>(PR_Settings.queueIdsByDeveloperName().values());
        for (Lead l : partnerLeads(newList)) {
            if (!prQueues.contains(l.OwnerId)) {
                Id queueId = PR_Settings.routeQueueId(l.State);
                if (queueId != null) l.OwnerId = queueId;
            }
            l.Is_Urgent__c = PR_Settings.isUrgent(l.Move_In_Date__c);
            if (l.SLA_Due_At__c == null) {
                l.SLA_Due_At__c = PR_Settings.slaDueFrom(now);
            }
            if (l.Status == PR_Settings.LEAD_WORKING && l.First_Contacted_At__c == null) {
                l.First_Contacted_At__c = now;
            }
        }
    }

    public static void beforeUpdate(List<Lead> newList, Map<Id, Lead> oldMap) {
        Datetime now = System.now();
        for (Lead l : partnerLeads(newList)) {
            if (l.IsConverted) continue;
            l.Is_Urgent__c = PR_Settings.isUrgent(l.Move_In_Date__c);
            if (l.Status == PR_Settings.LEAD_WORKING && l.First_Contacted_At__c == null) {
                l.First_Contacted_At__c = now;
            }
            if (l.SLA_Due_At__c != null) {
                Datetime contacted = l.First_Contacted_At__c;
                l.SLA_Breached__c = contacted != null ? contacted > l.SLA_Due_At__c : now > l.SLA_Due_At__c;
            }
        }
    }

    public static void afterInsert(List<Lead> newList) {
        List<Lead> leads = partnerLeads(newList);
        List<Lead> urgent = new List<Lead>();
        for (Lead l : leads) {
            if (l.Is_Urgent__c) urgent.add(l);
        }
        PR_Notifier.urgentLeads(urgent);
        PR_ReferralStatusSync.fromLeads(leads);
    }

    public static void afterUpdate(List<Lead> newList, Map<Id, Lead> oldMap) {
        List<Lead> becameUrgent = new List<Lead>();
        List<Lead> changed = new List<Lead>();
        List<Lead> converted = new List<Lead>();
        for (Lead l : partnerLeads(newList)) {
            Lead old = oldMap.get(l.Id);
            if (l.IsConverted && !old.IsConverted) {
                converted.add(l);
                continue;
            }
            if (l.Is_Urgent__c && !old.Is_Urgent__c) becameUrgent.add(l);
            if (l.Status != old.Status || l.OwnerId != old.OwnerId) changed.add(l);
        }
        PR_Notifier.urgentLeads(becameUrgent);
        PR_ReferralStatusSync.fromLeads(changed);
        PR_ConversionHandler.handle(converted);
    }
}
