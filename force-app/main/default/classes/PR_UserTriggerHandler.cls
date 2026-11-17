/**
 * 002 Partner referral (S01): when a Partner Manager enables an agency contact's login, the contact's
 * Portal Role decides the partner role (Principal = Executive, Agent = Worker) and permission set.
 */
public without sharing class PR_UserTriggerHandler {
    public static final String PS_AGENT = 'PR_Partner_Agent';
    public static final String PS_PRINCIPAL = 'PR_Partner_Principal';

    private static Map<Id, Contact> agencyContacts(List<User> users) {
        Set<Id> contactIds = new Set<Id>();
        for (User u : users) {
            if (u.ContactId != null) contactIds.add(u.ContactId);
        }
        if (contactIds.isEmpty()) {
            return new Map<Id, Contact>();
        }
        return new Map<Id, Contact>([
            SELECT Id, AccountId, Portal_Role__c
            FROM Contact
            WHERE Id IN :contactIds AND Account.Partner_Status__c != NULL
        ]);
    }

    public static void beforeInsert(List<User> newList) {
        Map<Id, Contact> contacts = agencyContacts(newList);
        for (User u : newList) {
            Contact c = contacts.get(u.ContactId);
            if (c == null) continue;
            u.PortalRole = c.Portal_Role__c == 'Principal' ? 'Executive' : 'Worker';
        }
    }

    public static void afterInsert(List<User> newList) {
        Map<Id, Contact> contacts = agencyContacts(newList);
        if (contacts.isEmpty()) {
            return;
        }
        Map<String, Id> ps = new Map<String, Id>();
        for (PermissionSet p : [SELECT Id, Name FROM PermissionSet WHERE Name IN (:PS_AGENT, :PS_PRINCIPAL)]) {
            ps.put(p.Name, p.Id);
        }
        List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
        Set<Id> principalAgencies = new Set<Id>();
        for (User u : newList) {
            Contact c = contacts.get(u.ContactId);
            if (c == null) continue;
            Boolean principal = c.Portal_Role__c == 'Principal';
            String name = principal ? PS_PRINCIPAL : PS_AGENT;
            if (ps.containsKey(name)) psas.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.get(name)));
            if (principal) principalAgencies.add(c.AccountId);
        }
        Database.insert(psas, false);
        if (!principalAgencies.isEmpty() && !System.isFuture() && !System.isBatch()) {
            PR_CommissionSharing.shareForAgencies(principalAgencies);
        }
    }
}
