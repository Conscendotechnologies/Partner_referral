/** Shared lookups and formatting for the Shift Fill agent actions. */
public with sharing class ShiftFillSupport {

    public class ShiftFillException extends Exception {}

    /** Accepts the open shift number (OS-00001) or its record Id. */
    public static Open_Shift__c findShift(String shiftRef) {
        if (String.isBlank(shiftRef)) {
            throw new ShiftFillException('Please give the open shift number, for example OS-00001.');
        }
        String ref = shiftRef.trim();
        List<Open_Shift__c> found = [SELECT Id FROM Open_Shift__c WHERE Name = :ref LIMIT 1];
        if (found.isEmpty() && (ref.length() == 15 || ref.length() == 18)) {
            found = [SELECT Id FROM Open_Shift__c WHERE Id = :ref LIMIT 1];
        }
        if (found.isEmpty()) {
            throw new ShiftFillException('No open shift found for ' + ref + '.');
        }
        return ShiftEligibilityService.loadShift(found[0].Id);
    }

    public static Nurse__c findNurse(String email) {
        String value = email == null ? '' : email.trim();
        List<Nurse__c> found = [SELECT Id, Name, Email__c, Employee_Number__c, Workday_Worker_ID__c, Home_Unit__c,
                                       Home_Unit__r.Name, Certifications__c, Certification_Expiry__c,
                                       Seniority_Date__c, Max_Weekly_Hours__c
                                FROM Nurse__c WHERE Email__c = :value LIMIT 1];
        if (found.isEmpty()) {
            throw new ShiftFillException('No nurse found with email ' + value + '.');
        }
        return found[0];
    }

    public static String describe(Open_Shift__c s) {
        Integer needed = s.Nurses_Needed__c == null ? 1 : s.Nurses_Needed__c.intValue();
        Integer filled = s.Nurses_Filled__c == null ? 0 : s.Nurses_Filled__c.intValue();
        return s.Name + ': ' + s.Unit__r.Name + ', ' + s.Shift_Date__c.format() + ' ' + s.Shift_Type__c
            + ' shift (' + (s.Shift_Hours__c == null ? 12 : s.Shift_Hours__c) + 'h), '
            + (needed - filled) + ' of ' + needed + ' still needed, status ' + s.Status__c;
    }
}
