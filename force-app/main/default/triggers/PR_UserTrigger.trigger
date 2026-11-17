trigger PR_UserTrigger on User (before insert, after insert) {
    if (Trigger.isBefore) PR_UserTriggerHandler.beforeInsert(Trigger.new);
    if (Trigger.isAfter) PR_UserTriggerHandler.afterInsert(Trigger.new);
}
