import { LightningElement } from 'lwc';
import getDashboard from '@salesforce/apex/StaffingCommandCenterController.getDashboard';
import getCandidates from '@salesforce/apex/StaffingCommandCenterController.getCandidates';
import runForecast from '@salesforce/apex/StaffingCommandCenterController.runForecast';

const CURRENCY = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });

function heat(probability) {
    if (probability >= 70) return 'cell cell-high';
    if (probability >= 50) return 'cell cell-mid';
    return 'cell cell-low';
}

export default class StaffingCommandCenter extends LightningElement {
    dashboard;
    candidates;
    selectedShift;
    busy = false;
    error;

    connectedCallback() {
        this.load();
    }

    get columns() {
        return this.dashboard ? this.dashboard.columns : [];
    }

    get rows() {
        if (!this.dashboard) return [];
        return this.dashboard.units.map((u) => ({
            ...u,
            cells: u.cells.map((c) => ({
                ...c,
                cls: heat(c.probability || 0),
                label: Math.round(c.probability || 0) + '%',
                title: `${u.unitName} ${c.shiftDate} ${c.shiftType}: need ${c.required}, have ${c.available}, gap ${c.gap}`
            }))
        }));
    }

    get openShifts() {
        if (!this.dashboard) return [];
        return this.dashboard.openShifts.map((s) => ({
            ...s,
            progress: `${s.filled} of ${s.needed} filled`,
            saved: CURRENCY.format(s.agencyCostAvoided || 0),
            assignedText: s.assigned && s.assigned.length ? s.assigned.join(', ') : 'Nobody yet',
            badgeClass: s.status === 'Filled' ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_warning'
        }));
    }

    get hasOpenShifts() {
        return this.openShifts.length > 0;
    }

    get kpis() {
        const d = this.dashboard || {};
        return [
            { label: 'Nurses (Workday)', value: d.headcount ?? '-' },
            { label: 'Shifts at risk (7 days)', value: d.atRiskShifts ?? '-' },
            { label: 'Nurses short', value: d.nursesShort ?? '-' },
            { label: 'Agency cost avoided', value: CURRENCY.format(d.agencyCostAvoided || 0) }
        ];
    }

    get eligibleCandidates() {
        return (this.candidates || []).filter((c) => c.eligible).map((c) => ({
            ...c,
            basis: `${c.homeUnitMatch ? 'Home unit' : 'Float'} · ${c.overtime4Weeks}h OT (4 wks) · seniority ${c.seniorityDate || 'n/a'}`
        }));
    }

    get excludedCandidates() {
        return (this.candidates || []).filter((c) => !c.eligible).slice(0, 8).map((c) => ({
            ...c,
            why: c.reasons.join('; ')
        }));
    }

    get excludedCount() {
        return (this.candidates || []).filter((c) => !c.eligible).length;
    }

    async load() {
        try {
            this.dashboard = await getDashboard();
            this.error = undefined;
        } catch (e) {
            this.error = e?.body?.message ?? e?.message;
        }
    }

    async handleRunForecast() {
        this.busy = true;
        try {
            await runForecast();
            await this.load();
        } catch (e) {
            this.error = e?.body?.message ?? e?.message;
        } finally {
            this.busy = false;
        }
    }

    async handleShowNurses(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedShift = this.openShifts.find((s) => s.id === id);
        this.busy = true;
        try {
            this.candidates = await getCandidates({ openShiftId: id });
        } catch (e) {
            this.error = e?.body?.message ?? e?.message;
        } finally {
            this.busy = false;
        }
    }

    handleRefresh() {
        this.candidates = undefined;
        this.selectedShift = undefined;
        this.load();
    }
}
