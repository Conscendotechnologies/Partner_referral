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

    /**
     * Decision F1: every commission is in the settings currency (AUD). Runs before the bypass check, because the
     * services write through the bypass and the payout sums amounts without converting them.
     */
    private static void requireCurrency(List<Partner_Commission__c> records, Boolean isInsert) {
        String cur = PR_Settings.currencyCode();
        // On insert the platform fills a blank currency with the creator's default before this trigger runs,
        // so a value equal to that default is treated as "not chosen" and stamped with the configured currency.
        // (An explicit choice of the creator's own default currency cannot be told apart and is stamped too.)
        String userDefault = UserInfo.getDefaultCurrency();
        for (Partner_Commission__c c : records) {
            Object code = c.get('CurrencyIsoCode');
            if (code == null || (isInsert && (String) code == userDefault)) {
                c.put('CurrencyIsoCode', cur);
            } else if ((String) code != cur) {
                c.addError('Partner commissions must be in ' + cur + '.');
            }
        }
    }

    public static void beforeInsert(List<Partner_Commission__c> newList) {
        requireCurrency(newList, true);
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
        requireCurrency(newList, false);
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
            // The key stops a second live commission for the same Opportunity. Only a valid cancellation
            // (below) or the commission service may clear it.
            Boolean cancelling = c.Status__c == PR_Settings.COM_CANCELLED && old.Status__c != PR_Settings.COM_CANCELLED;
            if (c.Opportunity_Key__c != old.Opportunity_Key__c && !(cancelling && c.Opportunity_Key__c == null)) {
                c.Opportunity_Key__c.addError('The Opportunity key is managed automatically and cannot be changed.');
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
