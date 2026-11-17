import { LightningElement, api } from 'lwc';
import getReferrals from '@salesforce/apex/PR_PortalController.getReferrals';

const STATUSES = ['Received', 'In Progress', 'Connected', 'Closed Lost'];
const BADGE = {
    Received: 'pr-badge pr-badge_received',
    'In Progress': 'pr-badge pr-badge_progress',
    Connected: 'pr-badge pr-badge_connected',
    'Closed Lost': 'pr-badge pr-badge_lost'
};

/**
 * 002 Partner referral (S04): referral tracking for partners. Sharing decides what comes back:
 * agents see what they sent, principals see the whole agency.
 */
export default class PrMyReferrals extends LightningElement {
    @api title = 'My referrals';
    /** Show who sent each referral (useful for principals). */
    @api showSubmitter = false;

    rows = [];
    status = '';
    loading = false;
    errorMessage;

    connectedCallback() {
        this.load();
    }

    get filters() {
        return [{ label: 'All', value: '' }, ...STATUSES.map((s) => ({ label: s, value: s }))].map((f) => ({
            ...f,
            pressed: String(f.value === this.status),
            cls: f.value === this.status ? 'pr-chip pr-chip_on' : 'pr-chip'
        }));
    }

    get isEmpty() {
        return !this.loading && !this.errorMessage && this.rows.length === 0;
    }

    get emptySuffix() {
        return this.status ? ` with status ${this.status}` : '';
    }

    handleFilter(event) {
        this.status = event.currentTarget.dataset.value;
        this.load();
    }

    @api
    refresh() {
        this.load();
    }

    /** Each load gets a number; only the latest one may update rows, errors or the loading state. */
    requestSeq = 0;

    async load() {
        const seq = ++this.requestSeq;
        this.loading = true;
        this.errorMessage = null;
        try {
            const data = await getReferrals({ statusFilter: this.status || null });
            if (seq !== this.requestSeq) return;
            this.rows = data.map((r) => ({
                ...r,
                badgeClass: BADGE[r.status] || 'pr-badge',
                repLabel: r.repFirstName || 'Not assigned yet'
            }));
        } catch (e) {
            if (seq !== this.requestSeq) return;
            this.errorMessage = e?.body?.message || 'Could not load referrals.';
        } finally {
            if (seq === this.requestSeq) this.loading = false;
        }
    }
}
