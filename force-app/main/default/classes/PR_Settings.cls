/**
 * 002 Partner referral: constants and settings (Partner_Referral_Setting__mdt "Default",
 * PR_State_Route__mdt, business hours, record types, queues).
 */
public inherited sharing class PR_Settings {
    public static final String RT_DEV_NAME = 'Partner_Referral';
    public static final String LEAD_SOURCE = 'Partner Referral';

    public static final String LEAD_NEW = 'New';
    public static final String LEAD_WORKING = 'Working';
    public static final String LEAD_QUALIFIED = 'Qualified';
    public static final String LEAD_UNQUALIFIED = 'Unqualified';
    public static final String LEAD_CONVERTED = 'Converted';

    public static final String STAGE_FIRST = 'Qualification';
    public static final String STAGE_WON = 'Utilities Connected';
    public static final String STAGE_LOST = 'Closed Lost';

    public static final String REF_RECEIVED = 'Received';
    public static final String REF_IN_PROGRESS = 'In Progress';
    public static final String REF_CONNECTED = 'Connected';
    public static final String REF_CLOSED_LOST = 'Closed Lost';

    public static final String AGENCY_ACTIVE = 'Active';

    public static final String COM_PENDING = 'Pending';
    public static final String COM_APPROVED = 'Approved';
    public static final String COM_IN_PAYOUT = 'Included in Payout';
    public static final String COM_PAID = 'Paid';
    public static final String COM_CANCELLED = 'Cancelled';

    public static final String BATCH_DRAFT = 'Draft';
    public static final String BATCH_EXPORTED = 'Exported';
    public static final String BATCH_PAID = 'Paid';

    public static final String PERM_MANAGE_AGENCIES = 'Manage_Partner_Agencies';
    public static final String PERM_APPROVE_COMMISSION = 'Approve_Partner_Commission';
    public static final String PERM_MANAGE_PAYOUTS = 'Manage_Partner_Payouts';
    public static final String PERM_PRINCIPAL = 'Partner_Principal';

    public static final List<String> STATES = new List<String>{ 'NSW', 'ACT', 'VIC', 'TAS', 'QLD', 'SA', 'WA', 'NT' };
    public static final List<String> UTILITIES = new List<String>{ 'Electricity', 'Gas', 'Water', 'Internet' };

    @TestVisible
    private static Partner_Referral_Setting__mdt cached;
    private static Map<String, Id> queueIds;
    private static Id bhId;

    public static Partner_Referral_Setting__mdt get() {
        if (cached == null) {
            // SOQL, not getInstance(): getInstance returns only the first 255 characters of a long text area,
            // and the consent wording the customer agrees to must never be cut off.
            List<Partner_Referral_Setting__mdt> rows = [
                SELECT Consent_Version__c, Consent_Text__c, Urgent_Window_Hours__c, SLA_Hours__c,
                    Business_Hours_Name__c, Fallback_Queue__c, Currency_Code__c, Price_Book_Name__c
                FROM Partner_Referral_Setting__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            cached = rows.isEmpty() ? null : rows[0];
            if (cached == null) {
                cached = new Partner_Referral_Setting__mdt(
                    Consent_Version__c = '1',
                    Consent_Text__c = 'The customer agrees to be contacted by Connectnow about connecting utilities.',
                    Urgent_Window_Hours__c = 48,
                    SLA_Hours__c = 2,
                    Business_Hours_Name__c = 'Connectnow Sales',
                    Fallback_Queue__c = 'PR_Unassigned',
                    Currency_Code__c = 'AUD',
                    Price_Book_Name__c = 'Partner Referral Utilities'
                );
            }
        }
        return cached;
    }

    public static String currencyCode() {
        return String.isBlank(get().Currency_Code__c) ? 'AUD' : get().Currency_Code__c;
    }

    public static Id leadRecordTypeId() {
        return Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get(RT_DEV_NAME).getRecordTypeId();
    }

    public static Id opportunityRecordTypeId() {
        return Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get(RT_DEV_NAME).getRecordTypeId();
    }

    /** Move-in within the urgent window (default 48 h), including dates already passed. */
    public static Boolean isUrgent(Date moveIn) {
        if (moveIn == null) {
            return false;
        }
        Integer days = (Integer) Math.ceil((get().Urgent_Window_Hours__c == null ? 48 : get().Urgent_Window_Hours__c) / 24);
        return moveIn <= Date.today().addDays(days);
    }

    public static Id businessHoursId() {
        if (bhId == null) {
            List<BusinessHours> bh = [
                SELECT Id
                FROM BusinessHours
                WHERE Name = :get().Business_Hours_Name__c AND IsActive = TRUE
                LIMIT 1
            ];
            if (bh.isEmpty()) {
                bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE LIMIT 1];
            }
            bhId = bh[0].Id;
        }
        return bhId;
    }

    public static Datetime slaDueFrom(Datetime start) {
        Decimal hours = get().SLA_Hours__c == null ? 2 : get().SLA_Hours__c;
        return BusinessHours.add(businessHoursId(), start, (Long) (hours * 60 * 60 * 1000));
    }

    public static Map<String, Id> queueIdsByDeveloperName() {
        if (queueIds == null) {
            queueIds = new Map<String, Id>();
            for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName LIKE 'PR%']) {
                queueIds.put(g.DeveloperName, g.Id);
            }
        }
        return queueIds;
    }

    /** Custom metadata cannot be inserted in tests; this lets a test supply route records. */
    @TestVisible
    private static List<PR_State_Route__mdt> routesOverride;

    /** State code -> queue Id, from PR_State_Route__mdt; falls back to the Unassigned queue. */
    public static Id routeQueueId(String stateCode) {
        Map<String, Id> queues = queueIdsByDeveloperName();
        if (String.isNotBlank(stateCode)) {
            for (PR_State_Route__mdt route : routesOverride != null ? routesOverride : PR_State_Route__mdt.getAll().values()) {
                if (String.isBlank(route.State_Codes__c)) continue;
                for (String code : route.State_Codes__c.split(',')) {
                    if (code.trim().equalsIgnoreCase(stateCode.trim()) && queues.containsKey(route.Queue_Developer_Name__c)) {
                        return queues.get(route.Queue_Developer_Name__c);
                    }
                }
            }
        }
        return queues.get(get().Fallback_Queue__c);
    }

    public static String periodFor(Date d) {
        return d.year() + '-' + String.valueOf(d.month()).leftPad(2, '0');
    }
}
