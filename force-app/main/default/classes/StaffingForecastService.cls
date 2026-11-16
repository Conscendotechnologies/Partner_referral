/**
 * Forecasts nurse staffing need per unit and shift for the coming days and
 * scores the probability of a shortage. Writes one Shift_Forecast__c per
 * unit/date/shift, keyed on Forecast_Key__c so reruns update in place.
 *
 * required  = projected census / ratio rule, plus one nurse per acuity point above 3.8
 * available = scheduled - time off - nurses whose certification lapses by the shift
 * shortage  = logistic(gap, flu index, unit overtime load) - a scoring model that
 *             stands in for a Data Cloud Model Builder prediction in the demo.
 */
public with sharing class StaffingForecastService {

    public static final Decimal SHIFT_HOURS = 12;

    @InvocableMethod(label='Run Staffing Forecast'
        description='Recalculates required nurses, available nurses and shortage probability for the next 7 days.')
    public static List<Integer> runInvocable(List<Integer> days) {
        Integer horizon = (days == null || days.isEmpty() || days[0] == null) ? 7 : days[0];
        return new List<Integer>{ run(Date.today(), horizon).size() };
    }

    public static List<Shift_Forecast__c> run(Date fromDate, Integer days) {
        Date startDate = fromDate.addDays(1);
        Date endDate = fromDate.addDays(days);

        Map<Id, Hospital_Unit__c> units = new Map<Id, Hospital_Unit__c>(
            [SELECT Id, Unit_Code__c, Patients_Per_Nurse__c FROM Hospital_Unit__c]);

        Map<String, Census_Snapshot__c> census = new Map<String, Census_Snapshot__c>();
        for (Census_Snapshot__c c : [SELECT Unit__c, Snapshot_Date__c, Shift_Type__c, Patient_Count__c, Acuity_Score__c
                                     FROM Census_Snapshot__c
                                     WHERE Snapshot_Date__c >= :startDate AND Snapshot_Date__c <= :endDate]) {
            census.put(key(c.Unit__c, c.Snapshot_Date__c, c.Shift_Type__c), c);
        }

        Map<String, Integer> available = new Map<String, Integer>();
        for (Shift_Schedule__c s : [SELECT Unit__c, Shift_Date__c, Shift_Type__c, Status__c,
                                           Nurse__r.Certification_Expiry__c
                                    FROM Shift_Schedule__c
                                    WHERE Shift_Date__c >= :startDate AND Shift_Date__c <= :endDate]) {
            String k = key(s.Unit__c, s.Shift_Date__c, s.Shift_Type__c);
            Boolean lapsed = s.Nurse__r.Certification_Expiry__c != null
                && s.Nurse__r.Certification_Expiry__c < s.Shift_Date__c;
            Integer add = (s.Status__c == 'Scheduled' && !lapsed) ? 1 : 0;
            available.put(k, (available.containsKey(k) ? available.get(k) : 0) + add);
        }

        Map<Date, Decimal> flu = new Map<Date, Decimal>();
        for (Demand_Signal__c d : [SELECT Signal_Date__c, Flu_Index__c FROM Demand_Signal__c
                                   WHERE Signal_Date__c >= :startDate AND Signal_Date__c <= :endDate]) {
            flu.put(d.Signal_Date__c, d.Flu_Index__c);
        }

        Map<Id, Decimal> unitOvertime = unitOvertimePerNurse(fromDate);

        List<Shift_Forecast__c> forecasts = new List<Shift_Forecast__c>();
        for (Hospital_Unit__c u : units.values()) {
            for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
                for (String shift : new List<String>{ 'Day', 'Night' }) {
                    Census_Snapshot__c c = census.get(key(u.Id, d, shift));
                    if (c == null) {
                        continue;
                    }
                    Integer required = requiredNurses(c.Patient_Count__c, c.Acuity_Score__c, u.Patients_Per_Nurse__c);
                    Integer avail = available.containsKey(key(u.Id, d, shift)) ? available.get(key(u.Id, d, shift)) : 0;
                    Integer gap = required - avail;
                    Decimal fluIndex = flu.containsKey(d) ? flu.get(d) : 5;
                    Decimal overtime = unitOvertime.containsKey(u.Id) ? unitOvertime.get(u.Id) : 0;

                    forecasts.add(new Shift_Forecast__c(
                        Forecast_Key__c = u.Unit_Code__c + '|' + String.valueOf(d) + '|' + shift,
                        Unit__c = u.Id,
                        Shift_Date__c = d,
                        Shift_Type__c = shift,
                        Projected_Census__c = c.Patient_Count__c,
                        Projected_Acuity__c = c.Acuity_Score__c,
                        Required_Nurses__c = required,
                        Available_Nurses__c = avail,
                        Ratio_Gap__c = gap,
                        Shortage_Probability__c = shortageProbability(gap, fluIndex, overtime)
                    ));
                }
            }
        }
        upsert forecasts Forecast_Key__c;
        return forecasts;
    }

    @TestVisible
    static Integer requiredNurses(Decimal patients, Decimal acuity, Decimal ratio) {
        Decimal base = patients / (ratio == null || ratio == 0 ? 4 : ratio);
        Decimal acuityLift = acuity == null ? 0 : Math.max(0, acuity - 3.8);
        return (Integer) (base + acuityLift).round(System.RoundingMode.HALF_UP);
    }

    /** Percent 0-100. */
    @TestVisible
    static Decimal shortageProbability(Integer gap, Decimal fluIndex, Decimal overtimePerNurse) {
        Double z = 1.4 * gap + 0.2 * (fluIndex - 6) + 0.05 * (overtimePerNurse - 4) - 2.0;
        return Decimal.valueOf(100 / (1 + Math.exp(-z))).setScale(1);
    }

    /** Average overtime hours per nurse over the last 4 weeks, by home unit. */
    private static Map<Id, Decimal> unitOvertimePerNurse(Date asOf) {
        Map<String, Id> unitByEmployee = new Map<String, Id>();
        Map<Id, Integer> headcount = new Map<Id, Integer>();
        for (Nurse__c n : [SELECT Employee_Number__c, Home_Unit__c FROM Nurse__c WHERE Home_Unit__c != null]) {
            unitByEmployee.put(n.Employee_Number__c, n.Home_Unit__c);
            headcount.put(n.Home_Unit__c, (headcount.containsKey(n.Home_Unit__c) ? headcount.get(n.Home_Unit__c) : 0) + 1);
        }
        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        Date since = asOf.addDays(-28);
        for (AggregateResult ar : [SELECT Employee_Number__c emp, SUM(Overtime_Hours__c) ot
                                   FROM Timekeeping_Entry__c
                                   WHERE Work_Date__c >= :since AND Work_Date__c < :asOf
                                   GROUP BY Employee_Number__c]) {
            Id unitId = unitByEmployee.get((String) ar.get('emp'));
            if (unitId != null && ar.get('ot') != null) {
                totals.put(unitId, (totals.containsKey(unitId) ? totals.get(unitId) : 0) + (Decimal) ar.get('ot'));
            }
        }
        Map<Id, Decimal> perNurse = new Map<Id, Decimal>();
        for (Id unitId : totals.keySet()) {
            perNurse.put(unitId, totals.get(unitId) / headcount.get(unitId));
        }
        return perNurse;
    }

    private static String key(Id unitId, Date d, String shift) {
        return unitId + '|' + String.valueOf(d) + '|' + shift;
    }
}
