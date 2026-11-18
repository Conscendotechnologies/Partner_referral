trigger PR_CommissionTrigger on Partner_Commission__c (before insert, before update, before delete, after insert) {
    if (Trigger.isBefore && Trigger.isDelete) PR_CommissionTriggerHandler.beforeDelete(Trigger.old);
    if (Trigger.isBefore && Trigger.isInsert) PR_CommissionTriggerHandler.beforeInsert(Trigger.new);
    if (Trigger.isBefore && Trigger.isUpdate) PR_CommissionTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    if (Trigger.isAfter && Trigger.isInsert) PR_CommissionTriggerHandler.afterInsert(Trigger.new);
}
