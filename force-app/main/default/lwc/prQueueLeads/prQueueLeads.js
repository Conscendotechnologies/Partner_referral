import { LightningElement } from 'lwc';
import getQueueLeads from '@salesforce/apex/PR_QueueLeadsController.getQueueLeads';

const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'url',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_self' }
    },
    { label: 'Urgent', fieldName: 'urgent', type: 'boolean', initialWidth: 90 },
    { label: 'Move-in Date', fieldName: 'moveInDate', type: 'date-local', initialWidth: 130 },
    { label: 'State', fieldName: 'state', initialWidth: 90 },
    { label: 'Status', fieldName: 'status', initialWidth: 110 },
    {
        label: 'First Contact Due',
        fieldName: 'firstContactDue',
        type: 'date',
        typeAttributes: { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }
    },
    { label: 'SLA Breached', fieldName: 'slaBreached', type: 'boolean', initialWidth: 120 },
    { label: 'Referring Agency', fieldName: 'agency' },
    { label: 'Queue', fieldName: 'queue' }
];

/**
 * 002 Partner referral (S03, AC-03.7): the rep's Partner Referral queues in one list, urgent movers first, then by
 * move-in date. The order comes from the server and the table does not re-sort it.
 */
export default class PrQueueLeads extends LightningElement {
    columns = COLUMNS;
    rows = [];
    hasMore = false;
    rowLimit;
    loading = false;
    errorMessage;

    connectedCallback() {
        this.load();
    }

    get isEmpty() {
        return !this.loading && !this.errorMessage && this.rows.length === 0;
    }

    get countLabel() {
        const urgent = this.rows.filter((r) => r.urgent).length;
        return this.hasMore
            ? `Showing the first ${this.rows.length} open (${urgent} urgent); more are in your queues`
            : `${this.rows.length} open, ${urgent} urgent`;
    }

    async load() {
        this.loading = true;
        this.errorMessage = null;
        try {
            const data = (await getQueueLeads()) || {};
            this.rows = (data.rows || []).map((r) => ({ ...r, url: '/' + r.id }));
            this.hasMore = !!data.hasMore;
            this.rowLimit = data.rowLimit;
        } catch (e) {
            this.rows = [];
            this.hasMore = false;
            this.errorMessage = (e && e.body && e.body.message) || 'The queue could not be loaded.';
        } finally {
            this.loading = false;
        }
    }

    handleRefresh() {
        this.load();
    }
}
