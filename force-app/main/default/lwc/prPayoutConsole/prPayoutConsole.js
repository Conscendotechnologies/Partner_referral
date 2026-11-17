import { LightningElement, api } from 'lwc';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getConsole from '@salesforce/apex/PR_PayoutController.getConsole';
import runPayout from '@salesforce/apex/PR_PayoutController.runPayout';
import exportCsv from '@salesforce/apex/PR_PayoutController.exportCsv';
import markPaid from '@salesforce/apex/PR_PayoutController.markPaid';

const BADGE = {
    Draft: 'slds-badge',
    Exported: 'slds-badge slds-theme_warning',
    Paid: 'slds-badge slds-theme_success'
};

/**
 * 002 Partner referral (S07): Finance console. Run the monthly payout (or re-run it the same day),
 * download the Xero CSV (moves the batch to Exported) and mark the batch Paid (cascades to commissions).
 * On a Payout Batch record page it shows only that batch.
 */
export default class PrPayoutConsole extends LightningElement {
    data;
    period;
    loading = false;
    errorMessage;
    message;
    _recordId;
    _connected = false;

    /**
     * On a record page Lightning can reuse this component for another batch. Reload when the record changes, so
     * Export and Mark paid never act on the batch that was shown before.
     */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        const changed = value !== this._recordId;
        this._recordId = value;
        if (changed && this._connected) {
            // Drop the previous batch at once: if the new load fails, nothing from the old batch stays on screen
            // or behind the Export and Mark paid buttons.
            this.data = null;
            this.message = null;
            this.errorMessage = null;
            this.load();
        }
    }

    /** Each load gets a number; only the latest one may update data, errors or the loading state. */
    _requestSeq = 0;

    connectedCallback() {
        this._connected = true;
        this.load();
    }

    disconnectedCallback() {
        this._connected = false;
        this._requestSeq++; // invalidate anything still in flight
    }

    /** Tells sibling components (the record detail panel) that the batch changed on the server. */
    async refreshRecord(batchId) {
        if (!batchId) return;
        try {
            await notifyRecordUpdateAvailable([{ recordId: batchId }]);
        } catch (e) {
            // A stale detail panel is cosmetic; never fail the payout action over it.
        }
    }

    async load() {
        const seq = ++this._requestSeq;
        this.loading = true;
        try {
            const data = await getConsole({ batchId: this.recordId || null });
            if (seq !== this._requestSeq) return; // superseded by a newer load (record changed)
            this.data = data;
            this.period = this.period || data.currentPeriod;
        } catch (e) {
            if (seq !== this._requestSeq) return;
            this.data = null;
            this.errorMessage = this.msg(e);
        } finally {
            if (seq === this._requestSeq) this.loading = false;
        }
    }

    get showRun() {
        return !this.recordId;
    }
    get cannotManage() {
        return !this.data?.canManage;
    }
    get readyCount() {
        return this.data?.readyCount ?? 0;
    }
    get readyTotal() {
        return this.data?.readyTotal ?? 0;
    }
    get batches() {
        const manage = this.data?.canManage;
        return (this.data?.batches || []).map((b) => ({
            ...b,
            url: `/lightning/r/Payout_Batch__c/${b.id}/view`,
            badge: BADGE[b.status] || 'slds-badge',
            cannotExport: !manage || b.status === 'Paid' || b.lineCount === 0,
            cannotPay: !manage || b.status !== 'Exported'
        }));
    }
    get noBatches() {
        return this.data && this.batches.length === 0;
    }

    handlePeriod(e) {
        this.period = e.detail.value;
    }

    async handleRun() {
        const input = this.template.querySelector('.pr-period');
        if (input && !input.reportValidity()) return;
        await this.act(async () => {
            await runPayout({ period: this.period });
            this.message = `Payout for ${this.period} is running. Refresh in a few seconds to see the lines.`;
            // the batch job is asynchronous: refresh once it has had time to run
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.load(), 4000);
        });
    }

    async handleExport(e) {
        const batchId = e.target.dataset.id;
        await this.act(async () => {
            const file = await exportCsv({ batchId });
            // Lightning Web Security blocks data: URIs in links; a Blob URL with an allowed MIME type works.
            const url = URL.createObjectURL(new Blob([file.body], { type: 'application/octet-stream' }));
            const link = document.createElement('a');
            link.href = url;
            link.download = file.fileName;
            link.click();
            URL.revokeObjectURL(url);
            this.message = `${file.fileName} downloaded. Upload it to Xero, then mark the batch paid.`;
        });
    }

    async handlePaid(e) {
        const batchId = e.target.dataset.id;
        await this.act(async () => {
            await markPaid({ batchId });
            this.message = 'Batch marked paid. Every commission in it is now Paid.';
        });
    }

    async act(fn) {
        // The batch the action changes: on a record page the console shows only that batch, so it is the record
        // shown when the action starts. Captured now, so navigating away mid-action still refreshes the right one.
        const actionBatchId = this.recordId;
        this.errorMessage = null;
        this.message = null;
        this.loading = true;
        try {
            await fn();
            await this.load();
            // On a Payout Batch record page, refresh the detail panel (status, paid date) next to this console.
            await this.refreshRecord(actionBatchId);
        } catch (err) {
            this.errorMessage = this.msg(err);
        } finally {
            this.loading = false;
        }
    }

    msg(e) {
        return e?.body?.message || e?.message || 'Something went wrong.';
    }
}
