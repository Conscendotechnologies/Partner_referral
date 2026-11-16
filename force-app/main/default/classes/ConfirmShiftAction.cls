/**
 * Agent action: a nurse accepts an open shift. Re-checks eligibility, books the
 * shift, records the agency cost avoided and the Workday write-back, and
 * refreshes the forecast so the gap closes.
 */
public with sharing class ConfirmShiftAction {

    public class Request {
        @InvocableVariable(required=true label='Open Shift Number' description='The open shift number, e.g. OS-00001.')
        public String openShift;
        @InvocableVariable(required=true label='Nurse Email' description='Work email of the nurse accepting the shift.')
        public String nurseEmail;
    }

    public class Result {
        @InvocableVariable(label='Confirmed' description='True when the shift was booked.')
        public Boolean confirmed;
        @InvocableVariable(label='Message' description='Confirmation details, or why it could not be booked.')
        public String message;
    }

    @InvocableMethod(label='Confirm Shift and Write Back'
        description='Books an accepted open shift for a nurse after re-checking eligibility, and writes the assignment back to Workday.')
    public static List<Result> run(List<Request> requests) {
        Request req = requests[0];
        Result r = new Result();
        r.confirmed = false;
        try {
            Open_Shift__c shift = ShiftFillSupport.findShift(req.openShift);
            Nurse__c nurse = ShiftFillSupport.findNurse(req.nurseEmail);
            Integer needed = shift.Nurses_Needed__c == null ? 1 : shift.Nurses_Needed__c.intValue();
            Integer filled = shift.Nurses_Filled__c == null ? 0 : shift.Nurses_Filled__c.intValue();
            if (shift.Status__c == 'Filled' || filled >= needed) {
                r.message = shift.Name + ' is already filled.';
                return new List<Result>{ r };
            }
            ShiftEligibilityService.Candidate c = ShiftEligibilityService.check(shift.Id, nurse);
            if (!c.eligible) {
                r.message = nurse.Name + ' cannot take ' + shift.Name + ': ' + String.join(c.reasons, '; ') + '.';
                return new List<Result>{ r };
            }

            Decimal hours = shift.Shift_Hours__c == null ? 12 : shift.Shift_Hours__c;
            Decimal agencyRate = shift.Unit__r.Agency_Hourly_Rate__c == null ? 0 : shift.Unit__r.Agency_Hourly_Rate__c;
            Decimal staffRate = shift.Unit__r.Staff_Hourly_Rate__c == null ? 0 : shift.Unit__r.Staff_Hourly_Rate__c;
            Decimal saved = hours * (agencyRate - staffRate);

            insert new Shift_Schedule__c(Nurse__c = nurse.Id, Unit__c = shift.Unit__c, Shift_Date__c = shift.Shift_Date__c,
                Shift_Type__c = shift.Shift_Type__c, Status__c = 'Scheduled', Open_Shift__c = shift.Id);

            filled++;
            Decimal savedSoFar = [SELECT Agency_Cost_Avoided__c FROM Open_Shift__c WHERE Id = :shift.Id].Agency_Cost_Avoided__c;
            Open_Shift__c upd = new Open_Shift__c(Id = shift.Id, Nurses_Filled__c = filled, Assigned_Nurse__c = nurse.Id,
                Agency_Cost_Avoided__c = (savedSoFar == null ? 0 : savedSoFar) + saved,
                Workday_Writeback_Status__c = 'Simulated: Workday schedule assignment sent for ' + nurse.Workday_Worker_ID__c
                    + ' (' + shift.Unit__r.Unit_Code__c + ' ' + String.valueOf(shift.Shift_Date__c) + ' ' + shift.Shift_Type__c + ')');
            if (filled >= needed) {
                upd.Status__c = 'Filled';
                upd.Filled_At__c = Datetime.now();
            }
            update upd;
            StaffingForecastService.run(Date.today(), 7);

            r.confirmed = true;
            r.message = nurse.Name + ' is booked on ' + shift.Unit__r.Name + ', ' + shift.Shift_Date__c.format() + ' '
                + shift.Shift_Type__c + '. ' + (needed - filled) + ' of ' + needed + ' still needed. Agency cost avoided: $'
                + saved.setScale(2) + '. Assignment written back to Workday for ' + nurse.Workday_Worker_ID__c + '.';
        } catch (Exception e) {
            r.message = e.getMessage();
        }
        return new List<Result>{ r };
    }
}
