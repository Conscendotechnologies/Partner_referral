import { LightningElement, api } from 'lwc';
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
    @api recordId;
    data;
    period;
    loading = false;
    errorMessage;
    message;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.data = await getConsole({ batchId: this.recordId || null });
            this.period = this.period || this.data.currentPeriod;
        } catch (e) {
            this.errorMessage = this.msg(e);
        } finally {
            this.loading = false;
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
        this.errorMessage = null;
        this.message = null;
        this.loading = true;
        try {
            await fn();
            await this.load();
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
