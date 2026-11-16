/** Agent action: check whether one nurse may take an open shift, with the reasons if not. */
public with sharing class CheckShiftEligibilityAction {

    public class Request {
        @InvocableVariable(required=true label='Open Shift Number' description='The open shift number, e.g. OS-00001.')
        public String openShift;
        @InvocableVariable(required=true label='Nurse Email' description='Work email of the nurse to check.')
        public String nurseEmail;
    }

    public class Result {
        @InvocableVariable(label='Eligible' description='True when the nurse passes every rule.')
        public Boolean eligible;
        @InvocableVariable(label='Summary' description='Plain-language result with the rule each failure broke.')
        public String summary;
    }

    @InvocableMethod(label='Check Shift Eligibility'
        description='Checks a nurse against certification, availability, rest-period, max-hours and overtime rules for an open shift.')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            try {
                Open_Shift__c shift = ShiftFillSupport.findShift(req.openShift);
                Nurse__c nurse = ShiftFillSupport.findNurse(req.nurseEmail);
                ShiftEligibilityService.Candidate c = ShiftEligibilityService.check(shift.Id, nurse);
                r.eligible = c.eligible;
                r.summary = c.eligible
                    ? nurse.Name + ' is eligible for ' + ShiftFillSupport.describe(shift) + '.'
                    : nurse.Name + ' is not eligible for ' + shift.Name + ': ' + String.join(c.reasons, '; ') + '.';
            } catch (Exception e) {
                r.eligible = false;
                r.summary = e.getMessage();
            }
            results.add(r);
        }
        return results;
    }
}
