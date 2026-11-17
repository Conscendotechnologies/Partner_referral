trigger PR_OpportunityTrigger on Opportunity (after update) {
    PR_OpportunityTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
