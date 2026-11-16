import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDocument from '@salesforce/apex/DocumentGeneratorController.getDocument';
import getSavedFiles from '@salesforce/apex/DocumentGeneratorController.getSavedFiles';
import savePdfToRecord from '@salesforce/apex/DocumentGeneratorController.savePdfToRecord';

/**
 * One component for every document in the demo. It never names an object -
 * the Document_Template__mdt record matching this page's object decides the
 * title, the fields shown, and whether line items appear.
 */
export default class DocumentGenerator extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    doc;
    docError;
    saving = false;

    filesResult;
    files = [];

    @wire(getDocument, { recordId: '$recordId' })
    wiredDocument({ data, error }) {
        if (data) {
            this.doc = data;
            this.docError = undefined;
        } else if (error) {
            this.doc = undefined;
            this.docError = this.readError(error);
        }
    }

    @wire(getSavedFiles, { recordId: '$recordId' })
    wiredFiles(result) {
        this.filesResult = result;
        if (result.data) {
            this.files = result.data;
        }
    }

    get hasDocument() {
        return !!this.doc;
    }

    get hasFiles() {
        return this.files && this.files.length > 0;
    }

    get accentStyle() {
        return this.doc ? `background-color: ${this.doc.accentColor};` : '';
    }

    get titleStyle() {
        return this.doc ? `color: ${this.doc.accentColor};` : '';
    }

    get cardTitle() {
        return this.doc ? this.doc.documentTitle : 'Document';
    }

    /** Opens the Visualforce PDF in a new tab - the browser handles the download. */
    handleDownload() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/apex/DocumentPdf?id=${this.recordId}`
            }
        });
    }

    /** Renders once and stores the result, so the issued PDF stops changing. */
    async handleSave() {
        this.saving = true;
        try {
            await savePdfToRecord({ recordId: this.recordId });
            await refreshApex(this.filesResult);
            this.toast('Saved', 'The PDF is now attached to this record.', 'success');
        } catch (error) {
            this.toast('Could not save', this.readError(error), 'error');
        } finally {
            this.saving = false;
        }
    }

    handleOpenFile(event) {
        const docId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: docId }
        });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    readError(error) {
        if (!error) {
            return 'Unknown error.';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Unknown error.';
    }
}
