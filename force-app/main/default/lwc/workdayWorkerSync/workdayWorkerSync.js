import { LightningElement } from 'lwc';
import getOverview from '@salesforce/apex/WorkdaySyncController.getOverview';
import compare from '@salesforce/apex/WorkdaySyncController.compare';
import startSync from '@salesforce/apex/WorkdaySyncController.startSync';
import getSyncStatus from '@salesforce/apex/WorkdaySyncController.getSyncStatus';

const POLL_MS = 3000;

const STATUS_CLASS = {
    'In sync': 'slds-text-color_success',
    Changed: 'slds-text-color_error',
    'Missing in Salesforce': 'slds-text-color_error'
};

const COLUMNS = [
    {
        label: 'Status', fieldName: 'status', initialWidth: 170,
        cellAttributes: { class: { fieldName: 'statusClass' } }
    },
    { label: 'Changed', fieldName: 'changedFields', initialWidth: 110 },
    {
        label: 'Worker', fieldName: 'contactUrl', type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_blank' }
    },
    { label: 'Title (Workday)', fieldName: 'workdayTitle' },
    { label: 'Title (Salesforce)', fieldName: 'salesforceTitle' },
    { label: 'Email (Workday)', fieldName: 'workdayEmail', type: 'email' },
    { label: 'Email (Salesforce)', fieldName: 'salesforceEmail', type: 'email' },
    { label: 'Org (Workday)', fieldName: 'workdayOrg' },
    { label: 'Org (Salesforce)', fieldName: 'salesforceOrg' }
];

export default class WorkdayWorkerSync extends LightningElement {
    columns = COLUMNS;
    overview = {};
    rows = [];
    workdayTotal;
    onlyDifferences = false;
    busy = false;
    syncMessage;
    error;
    pollHandle;

    connectedCallback() {
        this.loadOverview();
    }

    disconnectedCallback() {
        clearTimeout(this.pollHandle);
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get visibleRows() {
        return this.onlyDifferences ? this.rows.filter((r) => r.status !== 'In sync') : this.rows;
    }

    get workdayTotalLabel() {
        return this.workdayTotal ?? '-';
    }

    get outOfSyncLabel() {
        return this.hasRows ? this.rows.filter((r) => r.status !== 'In sync').length : '-';
    }

    async loadOverview() {
        try {
            this.overview = await getOverview();
        } catch (e) {
            this.error = this.message(e);
        }
    }

    async handleCompare() {
        this.busy = true;
        this.error = undefined;
        try {
            const result = await compare();
            this.workdayTotal = result.workdayTotal;
            this.rows = result.rows.map((r) => ({
                ...r,
                statusClass: STATUS_CLASS[r.status],
                contactUrl: r.contactId ? `/lightning/r/Contact/${r.contactId}/view` : undefined
            }));
            await this.loadOverview();
        } catch (e) {
            this.error = this.message(e);
        } finally {
            this.busy = false;
        }
    }

    async handleSync() {
        this.busy = true;
        this.error = undefined;
        try {
            await startSync();
            this.syncMessage = 'Sync running...';
            this.poll();
        } catch (e) {
            this.error = this.message(e);
            this.busy = false;
        }
    }

    poll() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.pollHandle = setTimeout(async () => {
            try {
                const status = await getSyncStatus();
                if (status === 'Running') {
                    this.poll();
                    return;
                }
                this.syncMessage = status === 'Completed' ? 'Sync completed' : undefined;
                if (status !== 'Completed') {
                    this.error = status;
                }
                this.busy = false;
                await this.handleCompare();
            } catch (e) {
                this.error = this.message(e);
                this.busy = false;
            }
        }, POLL_MS);
    }

    handleToggle(event) {
        this.onlyDifferences = event.target.checked;
    }

    message(e) {
        return e?.body?.message ?? e?.message ?? 'Unexpected error';
    }
}
