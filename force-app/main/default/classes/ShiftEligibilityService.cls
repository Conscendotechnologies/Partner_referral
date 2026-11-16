/**
 * Decides which nurses may take an open shift and ranks them. The guardrails
 * are the ones the Shift Fill agent must respect:
 *  - qualification: every certification the unit requires, none lapsed by the shift date
 *  - availability:  not already scheduled or on time off that day
 *  - rest period:   12-hour shifts (Day 07-19, Night 19-07) may not run back to back
 *  - max hours:     the shift must fit the nurse's weekly hour limit (7-day window)
 *  - overtime:      fewer than 24 overtime hours in the last 4 weeks
 * Ranking: home-unit nurses first, then least recent overtime (fairness), then
 * earliest seniority date (union seniority).
 */
public with sharing class ShiftEligibilityService {

    public static final Decimal OVERTIME_LIMIT = 24;

    public class Candidate {
        @AuraEnabled public Id nurseId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String homeUnit;
        @AuraEnabled public Boolean eligible = true;
        @AuraEnabled public List<String> reasons = new List<String>();
        @AuraEnabled public Decimal overtime4Weeks = 0;
        @AuraEnabled public Decimal weeklyHours = 0;
        @AuraEnabled public Date seniorityDate;
        @AuraEnabled public Boolean homeUnitMatch = false;
        @AuraEnabled public Integer rank;
    }

    /** Every nurse checked against the shift, eligible ones ranked first. */
    public static List<Candidate> evaluate(Id openShiftId) {
        Open_Shift__c shift = loadShift(openShiftId);
        return evaluate(shift, [SELECT Id, Name, Email__c, Employee_Number__c, Home_Unit__c, Home_Unit__r.Name,
                                       Certifications__c, Certification_Expiry__c, Seniority_Date__c, Max_Weekly_Hours__c
                                FROM Nurse__c]);
    }

    public static List<Candidate> eligible(Id openShiftId) {
        List<Candidate> result = new List<Candidate>();
        for (Candidate c : evaluate(openShiftId)) {
            if (c.eligible) {
                result.add(c);
            }
        }
        return result;
    }

    public static Candidate check(Id openShiftId, Nurse__c nurse) {
        return evaluate(loadShift(openShiftId), new List<Nurse__c>{ nurse })[0];
    }

    public static Open_Shift__c loadShift(Id openShiftId) {
        return [SELECT Id, Name, Unit__c, Unit__r.Name, Unit__r.Unit_Code__c, Unit__r.Required_Certifications__c,
                       Unit__r.Agency_Hourly_Rate__c, Unit__r.Staff_Hourly_Rate__c, Shift_Date__c, Shift_Type__c,
                       Status__c, Shift_Hours__c, Nurses_Needed__c, Nurses_Filled__c, Shift_Forecast__c
                FROM Open_Shift__c WHERE Id = :openShiftId];
    }

    private static List<Candidate> evaluate(Open_Shift__c shift, List<Nurse__c> nurses) {
        Date d = shift.Shift_Date__c;
        Decimal hours = shift.Shift_Hours__c == null ? 12 : shift.Shift_Hours__c;
        Set<String> requiredCerts = splitCerts(shift.Unit__r.Required_Certifications__c);

        Set<Id> nurseIds = new Map<Id, Nurse__c>(nurses).keySet();
        Map<Id, List<Shift_Schedule__c>> schedules = new Map<Id, List<Shift_Schedule__c>>();
        for (Shift_Schedule__c s : [SELECT Nurse__c, Shift_Date__c, Shift_Type__c, Status__c
                                    FROM Shift_Schedule__c
                                    WHERE Nurse__c IN :nurseIds
                                      AND Shift_Date__c >= :d.addDays(-6) AND Shift_Date__c <= :d.addDays(1)]) {
            if (!schedules.containsKey(s.Nurse__c)) {
                schedules.put(s.Nurse__c, new List<Shift_Schedule__c>());
            }
            schedules.get(s.Nurse__c).add(s);
        }

        Map<String, Decimal> overtime = new Map<String, Decimal>();
        Date since = Date.today().addDays(-28);
        for (AggregateResult ar : [SELECT Employee_Number__c emp, SUM(Overtime_Hours__c) ot FROM Timekeeping_Entry__c
                                   WHERE Work_Date__c >= :since GROUP BY Employee_Number__c]) {
            overtime.put((String) ar.get('emp'), ar.get('ot') == null ? 0 : (Decimal) ar.get('ot'));
        }

        List<Candidate> candidates = new List<Candidate>();
        for (Nurse__c n : nurses) {
            Candidate c = new Candidate();
            c.nurseId = n.Id;
            c.name = n.Name;
            c.email = n.Email__c;
            c.homeUnit = n.Home_Unit__r?.Name;
            c.homeUnitMatch = n.Home_Unit__c == shift.Unit__c;
            c.seniorityDate = n.Seniority_Date__c;
            c.overtime4Weeks = overtime.containsKey(n.Employee_Number__c) ? overtime.get(n.Employee_Number__c) : 0;

            Set<String> missing = requiredCerts.clone();
            missing.removeAll(splitCerts(n.Certifications__c));
            if (!missing.isEmpty()) {
                c.reasons.add('Missing certification: ' + String.join(new List<String>(missing), ', '));
            }
            if (n.Certification_Expiry__c != null && n.Certification_Expiry__c < d) {
                c.reasons.add('Certification lapsed on ' + n.Certification_Expiry__c.format());
            }

            List<Shift_Schedule__c> mine = schedules.containsKey(n.Id) ? schedules.get(n.Id) : new List<Shift_Schedule__c>();
            for (Shift_Schedule__c s : mine) {
                if (s.Shift_Date__c == d) {
                    c.reasons.add(s.Status__c == 'Time Off' ? 'On time off that day' : 'Already scheduled that day (' + s.Shift_Type__c + ')');
                } else if (s.Status__c == 'Scheduled' && breaksRest(shift.Shift_Type__c, d, s)) {
                    c.reasons.add('Rest period: ' + s.Shift_Type__c + ' shift on ' + s.Shift_Date__c.format() + ' is back to back');
                }
                if (s.Status__c == 'Scheduled' && s.Shift_Date__c > d.addDays(-7) && s.Shift_Date__c <= d) {
                    c.weeklyHours += 12;
                }
            }
            Decimal maxHours = n.Max_Weekly_Hours__c == null ? 40 : n.Max_Weekly_Hours__c;
            if (c.weeklyHours + hours > maxHours) {
                c.reasons.add('Max hours: ' + (c.weeklyHours + hours) + 'h would exceed ' + maxHours + 'h limit');
            }
            if (c.overtime4Weeks >= OVERTIME_LIMIT) {
                c.reasons.add('Overtime: ' + c.overtime4Weeks + 'h in last 4 weeks (limit ' + OVERTIME_LIMIT + 'h)');
            }
            c.eligible = c.reasons.isEmpty();
            candidates.add(c);
        }

        List<Candidate> eligibleOnes = new List<Candidate>();
        List<Candidate> others = new List<Candidate>();
        for (Candidate c : candidates) {
            (c.eligible ? eligibleOnes : others).add(c);
        }
        eligibleOnes = sortCandidates(eligibleOnes);
        for (Integer i = 0; i < eligibleOnes.size(); i++) {
            eligibleOnes[i].rank = i + 1;
        }
        eligibleOnes.addAll(others);
        return eligibleOnes;
    }

    /** Day = 07:00-19:00, Night = 19:00-07:00 next day. Back-to-back shifts leave no rest. */
    private static Boolean breaksRest(String shiftType, Date d, Shift_Schedule__c other) {
        if (shiftType == 'Day') {
            return other.Shift_Type__c == 'Night' && other.Shift_Date__c == d.addDays(-1);
        }
        return other.Shift_Type__c == 'Day' && other.Shift_Date__c == d.addDays(1);
    }

    private static List<Candidate> sortCandidates(List<Candidate> items) {
        List<Candidate> sorted = items.clone();
        for (Integer i = 1; i < sorted.size(); i++) {
            Candidate cur = sorted[i];
            Integer j = i - 1;
            while (j >= 0 && compare(sorted[j], cur) > 0) {
                sorted[j + 1] = sorted[j];
                j--;
            }
            sorted[j + 1] = cur;
        }
        return sorted;
    }

    private static Integer compare(Candidate a, Candidate b) {
        if (a.homeUnitMatch != b.homeUnitMatch) {
            return a.homeUnitMatch ? -1 : 1;
        }
        if (a.overtime4Weeks != b.overtime4Weeks) {
            return a.overtime4Weeks < b.overtime4Weeks ? -1 : 1;
        }
        Date da = a.seniorityDate == null ? Date.today() : a.seniorityDate;
        Date db = b.seniorityDate == null ? Date.today() : b.seniorityDate;
        return da == db ? 0 : (da < db ? -1 : 1);
    }

    private static Set<String> splitCerts(String value) {
        Set<String> result = new Set<String>();
        if (String.isNotBlank(value)) {
            result.addAll(value.split(';'));
        }
        return result;
    }
}
