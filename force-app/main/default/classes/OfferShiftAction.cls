/** Agent action: rank the eligible nurses for an open shift and mark it offered to them. */
public with sharing class OfferShiftAction {

    public class Request {
        @InvocableVariable(required=true label='Open Shift Number' description='The open shift number, e.g. OS-00001.')
        public String openShift;
        @InvocableVariable(label='How Many' description='How many top-ranked nurses to offer to. Defaults to 5.')
        public Integer howMany;
    }

    public class Result {
        @InvocableVariable(label='Offered To' description='Ranked nurses the shift was offered to, with the ranking basis.')
        public String offeredTo;
        @InvocableVariable(label='Eligible Count' description='Total eligible nurses.')
        public Integer eligibleCount;
    }

    @InvocableMethod(label='Offer Shift'
        description='Ranks eligible nurses by qualification, fairness (least recent overtime) and union seniority, and offers the shift to the top ones.')
    public static List<Result> run(List<Request> requests) {
        Request req = requests[0];
        Result r = new Result();
        try {
            Open_Shift__c shift = ShiftFillSupport.findShift(req.openShift);
            List<ShiftEligibilityService.Candidate> eligible = ShiftEligibilityService.eligible(shift.Id);
            Integer n = Math.min(req.howMany == null ? 5 : req.howMany, eligible.size());
            List<String> lines = new List<String>();
            for (Integer i = 0; i < n; i++) {
                ShiftEligibilityService.Candidate c = eligible[i];
                lines.add(c.rank + '. ' + c.name + ' (' + c.email + ') - ' + c.homeUnit
                    + (c.homeUnitMatch ? ' (home unit)' : ' (float)') + ', ' + c.overtime4Weeks
                    + 'h overtime in 4 weeks, seniority ' + (c.seniorityDate == null ? 'n/a' : c.seniorityDate.format()));
            }
            r.eligibleCount = eligible.size();
            r.offeredTo = lines.isEmpty() ? 'No eligible nurses for ' + shift.Name + '.' : String.join(lines, '\n');
            if (!lines.isEmpty()) {
                update new Open_Shift__c(Id = shift.Id, Status__c = 'Offered', Offered_To__c = r.offeredTo);
            }
        } catch (Exception e) {
            r.offeredTo = e.getMessage();
            r.eligibleCount = 0;
        }
        return new List<Result>{ r };
    }
}
