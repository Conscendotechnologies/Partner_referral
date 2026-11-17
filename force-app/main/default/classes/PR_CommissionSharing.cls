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

    /**
     * Called after a principal's login is enabled: their role may be new, so share the agency's history.
     * Runs as a chained Queueable, one agency and at most PAGE commissions per transaction, so a bulk enablement
     * across many agencies (or one agency with a long history) never exceeds the 10,000-row DML limit.
     */
    public static void shareForAgencies(Set<Id> agencyIds) {
        if (agencyIds == null || agencyIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new ShareHistoryJob(new List<Id>(agencyIds), null));
    }

    @TestVisible
    private static Integer PAGE = 5000;

    /** Number of ShareHistoryJob executions in this context (tests assert paging really happened). */
    @TestVisible
    private static Integer shareJobExecutions = 0;

    public class ShareHistoryJob implements Queueable {
        private List<Id> agencyIds;
        private Id afterId;

        public ShareHistoryJob(List<Id> agencyIds, Id afterId) {
            this.agencyIds = agencyIds;
            this.afterId = afterId;
        }

        public void execute(QueueableContext ctx) {
            shareJobExecutions++;
            Id agencyId = agencyIds[0];
            String soql = 'SELECT Id, Agency__c FROM Partner_Commission__c WHERE Agency__c = :agencyId' +
                (afterId == null ? '' : ' AND Id > :afterId') + ' ORDER BY Id LIMIT :page';
            List<Partner_Commission__c> rows = (List<Partner_Commission__c>) Database.queryWithBinds(
                soql,
                new Map<String, Object>{ 'agencyId' => agencyId, 'afterId' => afterId, 'page' => PAGE },
                AccessLevel.SYSTEM_MODE
            );
            share(rows);

            ShareHistoryJob next;
            if (rows.size() == PAGE) {
                next = new ShareHistoryJob(agencyIds, rows[rows.size() - 1].Id);
            } else if (agencyIds.size() > 1) {
                List<Id> rest = agencyIds.clone();
                rest.remove(0);
                next = new ShareHistoryJob(rest, null);
            }
            if (next != null && !Test.isRunningTest()) {
                System.enqueueJob(next);
            } else if (next != null) {
                next.execute(null);
            }
        }
    }
}
