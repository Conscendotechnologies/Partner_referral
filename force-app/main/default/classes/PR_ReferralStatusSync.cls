/**
 * 002 Partner referral (S04): the only path that writes the partner-facing status and rep first name.
 * Lead: New = Received; Working/Qualified = In Progress; Unqualified = Closed Lost.
 * Opportunity: open = In Progress; Utilities Connected = Connected; Closed Lost = Closed Lost.
 * Partners never see loss reasons, plans, notes or the rep's surname.
 */
public without sharing class PR_ReferralStatusSync {
    public static String statusForLead(String leadStatus) {
        if (leadStatus == PR_Settings.LEAD_NEW) return PR_Settings.REF_RECEIVED;
        if (leadStatus == PR_Settings.LEAD_WORKING || leadStatus == PR_Settings.LEAD_QUALIFIED) return PR_Settings.REF_IN_PROGRESS;
        if (leadStatus == PR_Settings.LEAD_UNQUALIFIED) return PR_Settings.REF_CLOSED_LOST;
        return null;
    }

    public static String statusForStage(String stage) {
        if (stage == PR_Settings.STAGE_WON) return PR_Settings.REF_CONNECTED;
        if (stage == PR_Settings.STAGE_LOST) return PR_Settings.REF_CLOSED_LOST;
        return PR_Settings.REF_IN_PROGRESS;
    }

    public static void fromLeads(List<Lead> leads) {
        Map<Id, String> status = new Map<Id, String>();
        Map<Id, Id> owner = new Map<Id, Id>();
        for (Lead l : leads) {
            if (l.Referral__c == null || l.IsConverted) continue;
            String s = statusForLead(l.Status);
            if (s == null) continue;
            status.put(l.Referral__c, s);
            owner.put(l.Referral__c, l.OwnerId);
        }
        apply(status, owner);
    }

    public static void fromOpportunities(List<Opportunity> opps) {
        Map<Id, String> status = new Map<Id, String>();
        Map<Id, Id> owner = new Map<Id, Id>();
        for (Opportunity o : opps) {
            if (o.Referral__c == null) continue;
            status.put(o.Referral__c, statusForStage(o.StageName));
            owner.put(o.Referral__c, o.OwnerId);
        }
        apply(status, owner);
    }

    private static void apply(Map<Id, String> status, Map<Id, Id> owner) {
        if (status.isEmpty()) {
            return;
        }
        Set<Id> userIds = new Set<Id>();
        for (Id o : owner.values()) {
            if (String.valueOf(o).startsWith('005')) userIds.add(o);
        }
        Map<Id, User> users = new Map<Id, User>([SELECT Id, FirstName FROM User WHERE Id IN :userIds]);
        List<Referral__c> updates = new List<Referral__c>();
        for (Referral__c r : [SELECT Id, Partner_Status__c, Rep_First_Name__c FROM Referral__c WHERE Id IN :status.keySet()]) {
            User u = users.get(owner.get(r.Id));
            String rep = u == null ? null : u.FirstName;
            if (r.Partner_Status__c != status.get(r.Id) || r.Rep_First_Name__c != rep) {
                updates.add(new Referral__c(Id = r.Id, Partner_Status__c = status.get(r.Id), Rep_First_Name__c = rep));
            }
        }
        update updates;
    }
}
