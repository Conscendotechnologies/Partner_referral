/**
 * 002 Partner referral (S03): urgent mover alerts. Bell notification to the lead owner (queue or rep)
 * plus an email to the queue's members. Alerts never block the save.
 */
public without sharing class PR_Notifier {
    @TestVisible
    private static Integer sentCount = 0;

    public static void urgentLeads(List<Lead> leads) {
        if (leads == null || leads.isEmpty()) {
            return;
        }
        List<CustomNotificationType> types = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Urgent_Partner_Referral'
            LIMIT 1
        ];
        Set<Id> queueIds = new Set<Id>();
        for (Lead l : leads) {
            if (String.valueOf(l.OwnerId).startsWith('00G')) queueIds.add(l.OwnerId);
        }
        Map<Id, List<Id>> membersByQueue = new Map<Id, List<Id>>();
        for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :queueIds]) {
            if (!String.valueOf(gm.UserOrGroupId).startsWith('005')) continue;
            if (!membersByQueue.containsKey(gm.GroupId)) membersByQueue.put(gm.GroupId, new List<Id>());
            membersByQueue.get(gm.GroupId).add(gm.UserOrGroupId);
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Lead l : leads) {
            String title = 'Urgent referral: ' + l.FirstName + ' ' + l.LastName + ' moves in ' + l.Move_In_Date__c.format();
            String body = 'Partner referral for ' + l.City + ' ' + l.State + '. Services: ' +
                (l.Utilities__c == null ? '' : l.Utilities__c.replace(';', ', ')) + '. Call within 2 business hours.';
            if (!types.isEmpty()) {
                try {
                    Messaging.CustomNotification n = new Messaging.CustomNotification();
                    n.setNotificationTypeId(types[0].Id);
                    n.setTargetId(l.Id);
                    n.setTitle(title);
                    n.setBody(body);
                    n.send(new Set<String>{ String.valueOf(l.OwnerId) });
                    sentCount++;
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'PR urgent notification not sent: ' + e.getMessage());
                }
            }
            for (Id userId : membersByQueue.containsKey(l.OwnerId) ? membersByQueue.get(l.OwnerId) : new List<Id>()) {
                Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
                m.setTargetObjectId(userId);
                m.setSaveAsActivity(false);
                m.setSubject(title);
                m.setPlainTextBody(body + '\n\n' + Url.getOrgDomainUrl().toExternalForm() + '/' + l.Id);
                emails.add(m);
            }
        }
        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'PR urgent email not sent: ' + e.getMessage());
            }
        }
    }
}
