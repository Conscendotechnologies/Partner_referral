import { createElement } from 'lwc';
import PrPayoutConsole from 'c/prPayoutConsole';
import getConsole from '@salesforce/apex/PR_PayoutController.getConsole';
import markPaid from '@salesforce/apex/PR_PayoutController.markPaid';
import exportCsv from '@salesforce/apex/PR_PayoutController.exportCsv';
import runPayout from '@salesforce/apex/PR_PayoutController.runPayout';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

jest.mock('@salesforce/apex/PR_PayoutController.getConsole', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PR_PayoutController.runPayout', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PR_PayoutController.exportCsv', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PR_PayoutController.markPaid', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('lightning/uiRecordApi', () => ({ notifyRecordUpdateAvailable: jest.fn(() => Promise.resolve()) }), { virtual: true });

const PERIOD = { a01A: '2026-10', a01B: '2026-11' };

/** A promise the test resolves or rejects when it chooses, to simulate slow or out-of-order server responses. */
function deferred() {
    let resolve;
    let reject;
    const promise = new Promise((res, rej) => {
        resolve = res;
        reject = rej;
    });
    return { promise, resolve, reject };
}

function consoleFor(batchId, status = 'Exported') {
    return {
        canManage: true,
        currentPeriod: '2026-11',
        readyCount: 0,
        readyTotal: 0,
        batches: [{ id: batchId, name: 'Batch ' + PERIOD[batchId], period: PERIOD[batchId], status, total: 100, runCount: 1, lineCount: 1 }]
    };
}

/** Each batch's own data, like the real controller. */
const loadsTheRequestedBatch = ({ batchId }) => Promise.resolve(consoleFor(batchId));

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function shownPeriods(element) {
    return [...element.shadowRoot.querySelectorAll('tbody tr th a')].map((a) => a.textContent);
}

function text(element) {
    return element.shadowRoot.textContent;
}

function button(element, label) {
    return [...element.shadowRoot.querySelectorAll('lightning-button')].find((b) => b.label === label);
}

async function mountOn(recordId) {
    const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
    element.recordId = recordId;
    document.body.appendChild(element);
    await flush();
    return element;
}

describe('c-pr-payout-console on a Payout Batch record page', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
        getConsole.mockReset();
        markPaid.mockReset();
        exportCsv.mockReset();
        runPayout.mockReset();
    });

    it('ignores an older response that arrives after the newer one (out-of-order loads)', async () => {
        const loadA = deferred();
        const loadB = deferred();
        getConsole.mockReturnValueOnce(loadA.promise).mockReturnValueOnce(loadB.promise);

        const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
        element.recordId = 'a01A';
        document.body.appendChild(element);
        element.recordId = 'a01B';

        loadB.resolve(consoleFor('a01B'));
        await flush();
        loadA.resolve(consoleFor('a01A'));
        await flush();

        expect(shownPeriods(element)).toEqual(['2026-11']);
    });

    it('shows nothing from the previous batch when the reload for the new record fails', async () => {
        getConsole.mockImplementationOnce(loadsTheRequestedBatch);
        const element = await mountOn('a01A');
        expect(shownPeriods(element)).toEqual(['2026-10']);

        getConsole.mockRejectedValueOnce({ body: { message: 'Insufficient access' } });
        element.recordId = 'a01B';
        await flush();

        expect(shownPeriods(element)).toEqual([]);
        expect(text(element)).toContain('Insufficient access');
    });

    it('ignores a load that finishes after the component was disconnected and reconnected', async () => {
        const late = deferred();
        getConsole.mockReturnValueOnce(late.promise).mockImplementation(loadsTheRequestedBatch);
        const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
        element.recordId = 'a01A';
        document.body.appendChild(element);

        document.body.removeChild(element); // disconnect while the first load is pending
        element.recordId = 'a01B';
        document.body.appendChild(element); // reconnect on another batch
        await flush();
        late.resolve(consoleFor('a01A')); // the stale first load lands last
        await flush();

        expect(shownPeriods(element)).toEqual(['2026-11']);
    });

    it('drops the previous batch when it reconnects on a different record, before the new load returns', async () => {
        getConsole.mockImplementationOnce(loadsTheRequestedBatch);
        const element = await mountOn('a01A');
        expect(shownPeriods(element)).toEqual(['2026-10']);

        document.body.removeChild(element);
        element.recordId = 'a01B';
        const pendingB = deferred();
        getConsole.mockReturnValueOnce(pendingB.promise);
        document.body.appendChild(element);
        await flush();

        expect(shownPeriods(element)).toEqual([]); // nothing from A, and no A buttons, while B loads
        pendingB.resolve(consoleFor('a01B'));
        await flush();
        expect(shownPeriods(element)).toEqual(['2026-11']);
    });

    it('refreshes the batch the action changed and keeps its success message off the next record', async () => {
        getConsole.mockImplementation(loadsTheRequestedBatch);
        const paid = deferred();
        markPaid.mockReturnValueOnce(paid.promise);
        const element = await mountOn('a01A');

        button(element, 'Mark paid').dispatchEvent(new CustomEvent('click'));
        await flush();
        element.recordId = 'a01B';
        await flush();
        paid.resolve('Paid');
        await flush();
        await flush();

        expect(markPaid).toHaveBeenCalledWith({ batchId: 'a01A' });
        expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{ recordId: 'a01A' }]);
        expect(notifyRecordUpdateAvailable).not.toHaveBeenCalledWith([{ recordId: 'a01B' }]);
        expect(shownPeriods(element)).toEqual(['2026-11']);
        expect(text(element)).not.toContain('marked paid');
    });

    it('keeps an action failure off the next record, but still reports it on the same record', async () => {
        getConsole.mockImplementation(loadsTheRequestedBatch);
        const failing = deferred();
        markPaid.mockReturnValueOnce(failing.promise);
        const element = await mountOn('a01A');

        button(element, 'Mark paid').dispatchEvent(new CustomEvent('click'));
        await flush();
        element.recordId = 'a01B';
        await flush();
        failing.reject({ body: { message: 'Download the Xero CSV first' } });
        await flush();
        expect(text(element)).not.toContain('Download the Xero CSV first');
        expect(shownPeriods(element)).toEqual(['2026-11']);

        // Same record throughout: the error is shown.
        markPaid.mockRejectedValueOnce({ body: { message: 'Only Finance can mark batches paid' } });
        button(element, 'Mark paid').dispatchEvent(new CustomEvent('click'));
        await flush();
        await flush();
        expect(text(element)).toContain('Only Finance can mark batches paid');
    });

    describe('on the Payouts app page (no record)', () => {
        const settle = async () => {
            for (let n = 0; n < 10; n++) await Promise.resolve();
        };

        afterEach(() => jest.useRealTimers());

        it('does not reload after Run payout if the console was left before the run finished', async () => {
            jest.useFakeTimers();
            getConsole.mockResolvedValue({ canManage: true, currentPeriod: '2026-11', readyCount: 3, readyTotal: 300, batches: [] });
            const running = deferred();
            runPayout.mockReturnValueOnce(running.promise);
            const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
            document.body.appendChild(element);
            await settle();
            const loadsBefore = getConsole.mock.calls.length;

            element.shadowRoot.querySelector('.pr-period').reportValidity = () => true; // stub has no validity API
            button(element, 'Run payout').dispatchEvent(new CustomEvent('click'));
            await settle();
            document.body.removeChild(element); // the user leaves before the run returns
            running.resolve('a0Bbatch');
            await settle();
            jest.advanceTimersByTime(5000); // the delayed refresh would fire here
            await settle();

            expect(runPayout).toHaveBeenCalledWith({ period: '2026-11' });
            expect(getConsole.mock.calls.length).toBe(loadsBefore); // no load for a page that is gone
        });

        it('still refreshes after Run payout while the console stays open', async () => {
            jest.useFakeTimers();
            getConsole.mockResolvedValue({ canManage: true, currentPeriod: '2026-11', readyCount: 3, readyTotal: 300, batches: [] });
            runPayout.mockResolvedValueOnce('a0Bbatch');
            const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
            document.body.appendChild(element);
            await settle();

            element.shadowRoot.querySelector('.pr-period').reportValidity = () => true; // stub has no validity API
            button(element, 'Run payout').dispatchEvent(new CustomEvent('click'));
            await settle();
            const loadsAfterRun = getConsole.mock.calls.length;
            jest.advanceTimersByTime(5000);
            await settle();

            expect(getConsole.mock.calls.length).toBe(loadsAfterRun + 1); // the delayed refresh ran once
        });
    });

    describe('with a CSV export', () => {
        beforeEach(() => {
            global.URL.createObjectURL = jest.fn(() => 'blob:csv');
            global.URL.revokeObjectURL = jest.fn();
        });

        it('reloads the batch when the user is back on it (A -> B -> A) before the export finishes', async () => {
            // A starts as Draft; after the export the server reports it Exported.
            let aStatus = 'Draft';
            getConsole.mockImplementation(({ batchId }) => Promise.resolve(consoleFor(batchId, batchId === 'a01A' ? aStatus : 'Draft')));
            const exporting = deferred();
            exportCsv.mockReturnValueOnce(exporting.promise);
            const element = await mountOn('a01A');
            expect(button(element, 'Mark paid').disabled).toBe(true); // Draft: not exported yet

            button(element, 'Download Xero CSV').dispatchEvent(new CustomEvent('click'));
            await flush();
            element.recordId = 'a01B';
            await flush();
            element.recordId = 'a01A'; // back on A; A reloads while the export is still running
            await flush();
            aStatus = 'Exported';
            exporting.resolve({ fileName: 'connectnow-commissions-2026-10.csv', body: 'a,b\n' });
            await flush();
            await flush();

            expect(button(element, 'Mark paid').disabled).toBe(false); // A's data reflects the finished export
            expect(text(element)).not.toContain('downloaded'); // the message belongs to the earlier visit
        });

        it('a stale action never erases the current record\x27s message', async () => {
            getConsole.mockImplementation(({ batchId }) => Promise.resolve(consoleFor(batchId, batchId === 'a01B' ? 'Draft' : 'Exported')));
            const paidA = deferred();
            markPaid.mockReturnValueOnce(paidA.promise);
            exportCsv.mockResolvedValueOnce({ fileName: 'connectnow-commissions-2026-11.csv', body: 'a,b\n' });
            const element = await mountOn('a01A');

            button(element, 'Mark paid').dispatchEvent(new CustomEvent('click')); // on A, still running
            await flush();
            element.recordId = 'a01B';
            await flush();
            button(element, 'Download Xero CSV').dispatchEvent(new CustomEvent('click')); // on B, finishes
            await flush();
            await flush();
            expect(text(element)).toContain('connectnow-commissions-2026-11.csv downloaded');

            paidA.resolve('Paid'); // A's action lands late
            await flush();
            await flush();
            expect(text(element)).toContain('connectnow-commissions-2026-11.csv downloaded');
            expect(text(element)).not.toContain('marked paid');
        });
    });
});
