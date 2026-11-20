import { LightningElement, wire } from 'lwc';
import getFormConfig from '@salesforce/apex/PR_PortalController.getFormConfig';
import submitReferral from '@salesforce/apex/PR_PortalController.submitReferral';
import { MOBILE_PATTERN } from './mobilePattern';

const EMPTY = () => ({
    firstName: '',
    lastName: '',
    mobile: '',
    email: '',
    street: '',
    suburb: '',
    state: '',
    postcode: '',
    moveInDate: null,
    utilities: [],
    previousAddress: '',
    notes: '',
    consent: false
});

/**
 * 002 Partner referral (S02): one-page, mobile-first referral form for the Connectnow Partners portal.
 * Client checks are for speed only; PR_ReferralService re-checks every rule and stamps agent, agency and consent.
 */
export default class PrReferralForm extends LightningElement {
    form = EMPTY();
    config;
    loading = true;
    errorMessage;
    duplicates;
    result;
    mobilePattern = MOBILE_PATTERN;

    @wire(getFormConfig)
    wiredConfig({ data, error }) {
        if (data) {
            this.config = data;
            this.loading = false;
        } else if (error) {
            this.errorMessage = this.messageOf(error);
            this.loading = false;
        }
    }

    get agencyName() {
        return this.config?.agencyName;
    }
    get consentText() {
        return this.config?.consentText;
    }
    get minMoveIn() {
        return this.config?.minMoveIn;
    }
    get maxMoveIn() {
        return this.config?.maxMoveIn;
    }
    get blockedMessage() {
        if (!this.config) return null;
        if (!this.config.isPartner) return 'Referrals are submitted by partner agents from the Connectnow Partners portal.';
        if (!this.config.agencyActive) return 'Your agency is not active, so new referrals cannot be submitted. Contact your Connectnow Partner Manager.';
        return null;
    }
    get stateOptions() {
        return (this.config?.states || []).map((s) => ({ label: s, value: s }));
    }
    get utilityOptions() {
        return (this.config?.utilities || []).map((u) => ({ label: u, value: u }));
    }

    handleChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        this.form = { ...this.form, [id]: value };
        this.duplicates = null;
    }

    validate() {
        const fields = [...this.template.querySelectorAll('.pr-field')];
        let ok = fields.reduce((valid, f) => f.reportValidity() && valid, true);
        if (!this.form.consent) {
            ok = false;
            this.errorMessage = 'The customer must give consent before you send the referral.';
        }
        return ok;
    }

    handleSubmit() {
        this.errorMessage = null;
        if (!this.validate()) {
            this.errorMessage = this.errorMessage || 'Check the highlighted fields.';
            return;
        }
        this.send(false);
    }

    handleSubmitAnyway() {
        this.send(true);
    }

    handleCancelDuplicate() {
        this.duplicates = null;
    }

    async send(acknowledgeDuplicate) {
        // "Send anyway" skips the duplicate check, so a second tap while pending would create a second referral.
        if (this.loading) return;
        this.loading = true;
        this.errorMessage = null;
        try {
            const res = await submitReferral({ input: { ...this.form, acknowledgeDuplicate } });
            if (res.duplicateWarning) {
                this.duplicates = res.duplicates;
            } else {
                this.result = res;
                this.duplicates = null;
                this.dispatchEvent(new CustomEvent('referralsent', { detail: res }));
            }
        } catch (e) {
            this.errorMessage = this.messageOf(e);
        } finally {
            this.loading = false;
        }
    }

    handleReset() {
        this.form = EMPTY();
        this.result = null;
        this.duplicates = null;
        this.errorMessage = null;
    }

    messageOf(e) {
        return e?.body?.message || e?.message || 'Something went wrong. Try again.';
    }
}
