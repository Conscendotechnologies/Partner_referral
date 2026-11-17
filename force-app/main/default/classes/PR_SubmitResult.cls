/** 002 Partner referral: result of a portal referral submission (top-level for the LWC boundary). */
public class PR_SubmitResult {
    @AuraEnabled public Boolean saved = false;
    @AuraEnabled public Id referralId;
    @AuraEnabled public String referralNumber;
    @AuraEnabled public Boolean duplicateWarning = false;
    @AuraEnabled public List<String> duplicates = new List<String>();
}
