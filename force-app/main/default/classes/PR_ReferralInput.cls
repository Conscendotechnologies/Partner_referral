/** 002 Partner referral: referral form input sent from the portal LWC (top-level so it is supported at the LWC boundary). */
public class PR_ReferralInput {
    @AuraEnabled public String firstName { get; set; }
    @AuraEnabled public String lastName { get; set; }
    @AuraEnabled public String mobile { get; set; }
    @AuraEnabled public String email { get; set; }
    @AuraEnabled public String street { get; set; }
    @AuraEnabled public String suburb { get; set; }
    @AuraEnabled public String state { get; set; }
    @AuraEnabled public String postcode { get; set; }
    @AuraEnabled public String previousAddress { get; set; }
    @AuraEnabled public Date moveInDate { get; set; }
    @AuraEnabled public List<String> utilities { get; set; }
    @AuraEnabled public String notes { get; set; }
    @AuraEnabled public Boolean consent { get; set; }
    @AuraEnabled public Boolean acknowledgeDuplicate { get; set; }
}
