/**
 * 002 Partner referral (S06): commission controls.
 * - Amount, rate, services, Opportunity and agency can never be edited: cancel and recreate instead.
 * - Pending -> Approved needs Approve_Partner_Commission (stamps Approved By/On).
 * - Any change after approval needs Manage_Partner_Payouts; Included in Payout and Paid are set by the payout run.
 * - Cancelling needs a reason and frees the Opportunity Key.
 * - Agency principals get read access through Apex managed sharing.
 */
public without sharing class PR_CommissionTriggerHandler {
    private static final List<SObjectField> LOCKED = new List<SObjectField>{
        Partner_Commission__c.Amount__c,
        Partner_Commission__c.Rate_Applied__c,
        Partner_Commission__c.Services_Count__c,
        Partner_Commission__c.Opportunity__c,
        Partner_Commission__c.Agency__c
    };

    @TestVisible
    private static Boolean can(String permission) {
        return FeatureManagement.checkPermission(permission);
    }

    public static void beforeInsert(List<Partner_Commission__c> newList) {
        if (PR_CommissionService.bypassLocks) return;
        Boolean finance = can(PR_Settings.PERM_MANAGE_PAYOUTS);
        for (Partner_Commission__c c : newList) {
            if (!finance) {
                c.addError('Commissions are created automatically when an Opportunity reaches Utilities Connected.');
                continue;
            }
            c.Status__c = PR_Settings.COM_PENDING;
            c.Approved_By__c = null;
            c.Approved_On__c = null;
            c.Payout_Line__c = null;
        }
    }

    public static void beforeUpdate(List<Partner_Commission__c> newList, Map<Id, Partner_Commission__c> oldMap) {
        if (PR_CommissionService.bypassLocks) return;
        Boolean approver = can(PR_Settings.PERM_APPROVE_COMMISSION);
        Boolean finance = can(PR_Settings.PERM_MANAGE_PAYOUTS);
        for (Partner_Commission__c c : newList) {
            Partner_Commission__c old = oldMap.get(c.Id);
            for (SObjectField f : LOCKED) {
                if (c.get(f) != old.get(f)) {
                    c.addError('Amount, rate, services, Opportunity and agency cannot be changed. Cancel this commission and create a new one.');
                    break;
                }
            }
            if (c.Payout_Line__c != old.Payout_Line__c) {
                c.addError('Payout lines are set by the monthly payout run.');
            }
            if (c.Status__c == old.Status__c) {
                if (old.Status__c != PR_Settings.COM_PENDING && !finance && !onlyFlagChanged(c, old)) {
                    c.addError('Only Finance can change a commission after it is approved.');
                }
                continue;
            }
            String fromS = old.Status__c;
            String toS = c.Status__c;
            if (toS == PR_Settings.COM_IN_PAYOUT || toS == PR_Settings.COM_PAID) {
                c.addError('Included in Payout and Paid are set by the payout batch.');
            } else if (fromS == PR_Settings.COM_IN_PAYOUT || fromS == PR_Settings.COM_PAID || fromS == PR_Settings.COM_CANCELLED) {
                c.addError('A commission that is ' + fromS + ' cannot be changed.');
            } else if (toS == PR_Settings.COM_APPROVED) {
                if (!approver) {
                    c.addError('Only Partner Managers can approve commissions.');
                } else {
                    c.Approved_By__c = UserInfo.getUserId();
                    c.Approved_On__c = System.now();
                }
            } else if (toS == PR_Settings.COM_CANCELLED) {
                Boolean allowed = fromS == PR_Settings.COM_PENDING ? (approver || finance) : finance;
                if (!allowed) {
                    c.addError('You cannot cancel this commission.');
                } else if (String.isBlank(c.Cancellation_Reason__c)) {
                    c.Cancellation_Reason__c.addError('Give a reason for cancelling.');
                } else {
                    c.Opportunity_Key__c = null;
                }
            } else if (toS == PR_Settings.COM_PENDING) {
                if (!finance) {
                    c.addError('Only Finance can move an approved commission back to Pending.');
                } else {
                    c.Approved_By__c = null;
                    c.Approved_On__c = null;
                }
            }
        }
    }

    private static Boolean onlyFlagChanged(Partner_Commission__c c, Partner_Commission__c old) {
        return c.Cancellation_Reason__c == old.Cancellation_Reason__c && c.Approved_By__c == old.Approved_By__c &&
            c.Approved_On__c == old.Approved_On__c;
    }

    public static void afterInsert(List<Partner_Commission__c> newList) {
        PR_CommissionSharing.share(newList);
    }
}
