/**
 * 002 Partner referral (S06): read access for each agency's principals (partner Executive role) to that
 * agency's commissions, via Apex managed sharing. Agents (partner User role) never get it, and no agency
 * ever gets another agency's commissions (external OWD Private).
 */
public without sharing class PR_CommissionSharing {
    public static void share(List<Partner_Commission__c> commissions) {
        Set<Id> agencyIds = new Set<Id>();
        for (Partner_Commission__c c : commissions) {
            if (c.Agency__c != null) agencyIds.add(c.Agency__c);
        }
        if (agencyIds.isEmpty()) {
            return;
        }
        Map<Id, Id> agencyByRole = new Map<Id, Id>();
        for (UserRole r : [SELECT Id, PortalAccountId FROM UserRole WHERE PortalAccountId IN :agencyIds AND PortalRole = 'Executive']) {
            agencyByRole.put(r.Id, r.PortalAccountId);
        }
        Map<Id, Id> groupByAgency = new Map<Id, Id>();
        for (Group g : [SELECT Id, RelatedId FROM Group WHERE Type = 'Role' AND RelatedId IN :agencyByRole.keySet()]) {
            groupByAgency.put(agencyByRole.get(g.RelatedId), g.Id);
        }
        List<Partner_Commission__Share> shares = new List<Partner_Commission__Share>();
        for (Partner_Commission__c c : commissions) {
            Id groupId = groupByAgency.get(c.Agency__c);
            if (groupId == null) continue;
            shares.add(new Partner_Commission__Share(
                ParentId = c.Id,
                UserOrGroupId = groupId,
                AccessLevel = 'Read',
                RowCause = Schema.Partner_Commission__Share.RowCause.Agency_Principal__c
            ));
        }
        Database.insert(shares, false);
    }

    /** Called after a principal's login is enabled: their role may be new, so share the agency's history. */
    @future
    public static void shareForAgencies(Set<Id> agencyIds) {
        share([SELECT Id, Agency__c FROM Partner_Commission__c WHERE Agency__c IN :agencyIds]);
    }
}
