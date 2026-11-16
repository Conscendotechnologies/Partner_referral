/** Agent action: list open shifts that still need nurses. */
public with sharing class GetOpenShiftsAction {

    public class Request {
        @InvocableVariable(label='Unit Code' description='Optional unit code to filter by, e.g. ICU, MEDS, ED, PEDS.')
        public String unitCode;
    }

    public class Result {
        @InvocableVariable(label='Open Shifts' description='One line per open shift: number, unit, date, shift, nurses still needed.')
        public String openShifts;
        @InvocableVariable(label='Count' description='Number of open shifts found.')
        public Integer count;
    }

    @InvocableMethod(label='Get Open Shifts' description='Lists open nursing shifts that still need nurses, optionally for one unit.')
    public static List<Result> run(List<Request> requests) {
        String unitCode = (requests == null || requests.isEmpty()) ? null : requests[0].unitCode;
        List<String> lines = new List<String>();
        for (Open_Shift__c s : [SELECT Id, Name, Unit__r.Name, Unit__r.Unit_Code__c, Shift_Date__c, Shift_Type__c,
                                       Status__c, Shift_Hours__c, Nurses_Needed__c, Nurses_Filled__c
                                FROM Open_Shift__c
                                WHERE Status__c IN ('Open', 'Offered') AND Shift_Date__c >= TODAY
                                ORDER BY Shift_Date__c, Name]) {
            if (String.isBlank(unitCode) || s.Unit__r.Unit_Code__c == unitCode.trim().toUpperCase()) {
                lines.add(ShiftFillSupport.describe(s));
            }
        }
        Result r = new Result();
        r.count = lines.size();
        r.openShifts = lines.isEmpty() ? 'There are no open shifts right now.' : String.join(lines, '\n');
        return new List<Result>{ r };
    }
}
