trigger PR_LeadTrigger on Lead (before insert, before update, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) PR_LeadTriggerHandler.beforeInsert(Trigger.new);
    if (Trigger.isBefore && Trigger.isUpdate) PR_LeadTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    if (Trigger.isAfter && Trigger.isInsert) PR_LeadTriggerHandler.afterInsert(Trigger.new);
    if (Trigger.isAfter && Trigger.isUpdate) PR_LeadTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
