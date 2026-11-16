/** Apex surface for the staffingCommandCenter LWC. */
public with sharing class StaffingCommandCenterController {

    public class Cell {
        @AuraEnabled public String key;
        @AuraEnabled public String shiftDate;
        @AuraEnabled public String shiftType;
        @AuraEnabled public Integer required;
        @AuraEnabled public Integer available;
        @AuraEnabled public Integer gap;
        @AuraEnabled public Decimal probability;
    }

    public class UnitRow {
        @AuraEnabled public String unitName;
        @AuraEnabled public String unitCode;
        @AuraEnabled public List<Cell> cells = new List<Cell>();
    }

    public class OpenShiftView {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String unitName;
        @AuraEnabled public String shiftLabel;
        @AuraEnabled public String status;
        @AuraEnabled public Integer needed;
        @AuraEnabled public Integer filled;
        @AuraEnabled public Decimal agencyCostAvoided;
        @AuraEnabled public String writeback;
        @AuraEnabled public List<String> assigned = new List<String>();
    }

    public class Dashboard {
        @AuraEnabled public List<String> columns = new List<String>();
        @AuraEnabled public List<UnitRow> units = new List<UnitRow>();
        @AuraEnabled public List<OpenShiftView> openShifts = new List<OpenShiftView>();
        @AuraEnabled public Integer atRiskShifts = 0;
        @AuraEnabled public Integer nursesShort = 0;
        @AuraEnabled public Decimal agencyCostAvoided = 0;
        @AuraEnabled public Integer headcount;
    }

    @AuraEnabled
    public static Dashboard getDashboard() {
        Dashboard d = new Dashboard();
        d.headcount = [SELECT COUNT() FROM Nurse__c];

        Map<String, UnitRow> rows = new Map<String, UnitRow>();
        Set<String> columns = new Set<String>();
        for (Shift_Forecast__c f : [SELECT Unit__r.Name, Unit__r.Unit_Code__c, Shift_Date__c, Shift_Type__c,
                                           Required_Nurses__c, Available_Nurses__c, Ratio_Gap__c, Shortage_Probability__c
                                    FROM Shift_Forecast__c
                                    WHERE Shift_Date__c > TODAY AND Shift_Date__c <= NEXT_N_DAYS:7
                                    ORDER BY Unit__r.Name, Shift_Date__c, Shift_Type__c]) {
            UnitRow row = rows.get(f.Unit__r.Unit_Code__c);
            if (row == null) {
                row = new UnitRow();
                row.unitName = f.Unit__r.Name;
                row.unitCode = f.Unit__r.Unit_Code__c;
                rows.put(row.unitCode, row);
            }
            Cell c = new Cell();
            c.shiftDate = Datetime.newInstance(f.Shift_Date__c, Time.newInstance(12, 0, 0, 0)).format('EEE d MMM');
            c.shiftType = f.Shift_Type__c;
            c.key = row.unitCode + '|' + String.valueOf(f.Shift_Date__c) + '|' + f.Shift_Type__c;
            c.required = f.Required_Nurses__c == null ? 0 : f.Required_Nurses__c.intValue();
            c.available = f.Available_Nurses__c == null ? 0 : f.Available_Nurses__c.intValue();
            c.gap = f.Ratio_Gap__c == null ? 0 : f.Ratio_Gap__c.intValue();
            c.probability = f.Shortage_Probability__c;
            row.cells.add(c);
            columns.add(c.shiftDate + ' ' + c.shiftType);
            if (c.probability != null && c.probability >= 70) {
                d.atRiskShifts++;
                d.nursesShort += Math.max(0, c.gap);
            }
        }
        d.columns.addAll(columns);
        d.units = rows.values();

        Map<Id, OpenShiftView> views = new Map<Id, OpenShiftView>();
        for (Open_Shift__c s : [SELECT Id, Name, Unit__r.Name, Shift_Date__c, Shift_Type__c, Status__c, Nurses_Needed__c,
                                       Nurses_Filled__c, Agency_Cost_Avoided__c, Workday_Writeback_Status__c
                                FROM Open_Shift__c WHERE Shift_Date__c >= TODAY ORDER BY Shift_Date__c, Name]) {
            OpenShiftView v = new OpenShiftView();
            v.id = s.Id;
            v.name = s.Name;
            v.unitName = s.Unit__r.Name;
            v.shiftLabel = Datetime.newInstance(s.Shift_Date__c, Time.newInstance(12, 0, 0, 0)).format('EEE d MMM') + ' ' + s.Shift_Type__c;
            v.status = s.Status__c;
            v.needed = s.Nurses_Needed__c == null ? 1 : s.Nurses_Needed__c.intValue();
            v.filled = s.Nurses_Filled__c == null ? 0 : s.Nurses_Filled__c.intValue();
            v.agencyCostAvoided = s.Agency_Cost_Avoided__c == null ? 0 : s.Agency_Cost_Avoided__c;
            v.writeback = s.Workday_Writeback_Status__c;
            d.agencyCostAvoided += v.agencyCostAvoided;
            views.put(s.Id, v);
        }
        for (Shift_Schedule__c f : [SELECT Open_Shift__c, Nurse__r.Name FROM Shift_Schedule__c
                                    WHERE Open_Shift__c IN :views.keySet() ORDER BY CreatedDate]) {
            views.get(f.Open_Shift__c).assigned.add(f.Nurse__r.Name);
        }
        d.openShifts = views.values();
        return d;
    }

    @AuraEnabled
    public static List<ShiftEligibilityService.Candidate> getCandidates(Id openShiftId) {
        return ShiftEligibilityService.evaluate(openShiftId);
    }

    @AuraEnabled
    public static Integer runForecast() {
        return StaffingForecastService.run(Date.today(), 7).size();
    }
}
