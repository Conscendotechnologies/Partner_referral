/** 002 Partner referral: one referral as shown to partners on the portal (top-level for the LWC boundary). */
public class PR_ReferralRow {
    @AuraEnabled public Id id;
    @AuraEnabled public String referralNumber;
    @AuraEnabled public String moverName;
    @AuraEnabled public String suburb;
    @AuraEnabled public Date moveInDate;
    @AuraEnabled public String utilities;
    @AuraEnabled public String status;
    @AuraEnabled public String repFirstName;
    @AuraEnabled public String submittedBy;
    @AuraEnabled public Datetime submittedAt;
    @AuraEnabled public Boolean urgent;
}
