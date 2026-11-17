import { LightningElement } from 'lwc';
import getHomeSummary from '@salesforce/apex/PR_PortalController.getHomeSummary';

const ORDER = [
    ['Received', 'pr-tile pr-tile_received'],
    ['In Progress', 'pr-tile pr-tile_progress'],
    ['Connected', 'pr-tile pr-tile_connected'],
    ['Closed Lost', 'pr-tile pr-tile_lost']
];

/**
 * 002 Partner referral (S04): partner portal home. Leads this month by status for everyone;
 * commission this month and last month for principals only. Hosts the referral form and the referral list.
 */
export default class PrPortalHome extends LightningElement {
    summary;
    tab = 'refer';
    errorMessage;

    connectedCallback() {
        this.load();
    }

    /** Each load gets a number; an older response never replaces a newer summary or error. */
    requestSeq = 0;

    async load() {
        const seq = ++this.requestSeq;
        try {
            const summary = await getHomeSummary();
            if (seq !== this.requestSeq) return;
            this.summary = summary;
            this.errorMessage = null;
        } catch (e) {
            if (seq !== this.requestSeq) return;
            this.errorMessage = e?.body?.message || 'Could not load your summary.';
        }
    }

    get greeting() {
        return this.summary?.agencyName ? `Welcome, ${this.summary.agencyName}` : 'Welcome';
    }
    get total() {
        return this.summary?.totalThisMonth ?? 0;
    }
    get statusTiles() {
        const by = this.summary?.byStatus || {};
        return ORDER.map(([label, cls]) => ({ label, cls, value: by[label] ?? 0 }));
    }
    get isPrincipal() {
        return this.summary?.isPrincipal === true;
    }
    get commissionThisMonth() {
        return this.summary?.commissionThisMonth ?? 0;
    }
    get commissionLastMonth() {
        return this.summary?.commissionLastMonth ?? 0;
    }
    get listLabel() {
        return this.isPrincipal ? 'Agency referrals' : 'My referrals';
    }
    get isRefer() {
        return this.tab === 'refer';
    }
    get isList() {
        return this.tab === 'list';
    }
    get referTabClass() {
        return this.isRefer ? 'pr-tab pr-tab_on' : 'pr-tab';
    }
    get listTabClass() {
        return this.isList ? 'pr-tab pr-tab_on' : 'pr-tab';
    }

    handleTab(event) {
        this.tab = event.currentTarget.dataset.tab;
    }

    handleSent() {
        this.load();
    }
}
