import { createElement } from 'lwc';
import PrPayoutConsole from 'c/prPayoutConsole';
import getConsole from '@salesforce/apex/PR_PayoutController.getConsole';
import markPaid from '@salesforce/apex/PR_PayoutController.markPaid';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

jest.mock('@salesforce/apex/PR_PayoutController.getConsole', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PR_PayoutController.runPayout', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PR_PayoutController.exportCsv', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PR_PayoutController.markPaid', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('lightning/uiRecordApi', () => ({ notifyRecordUpdateAvailable: jest.fn(() => Promise.resolve()) }), { virtual: true });

/** A promise the test resolves or rejects when it chooses, to simulate out-of-order server responses. */
function deferred() {
    let resolve;
    let reject;
    const promise = new Promise((res, rej) => {
        resolve = res;
        reject = rej;
    });
    return { promise, resolve, reject };
}

function consoleFor(batchId, period, status = 'Exported') {
    return {
        canManage: true,
        currentPeriod: '2026-11',
        readyCount: 0,
        readyTotal: 0,
        batches: [{ id: batchId, name: 'Batch ' + period, period, status, total: 100, runCount: 1, lineCount: 1 }]
    };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function shownPeriods(element) {
    return [...element.shadowRoot.querySelectorAll('tbody tr th a')].map((a) => a.textContent);
}

describe('c-pr-payout-console on a Payout Batch record page', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
    });

    it('ignores an older response that arrives after the newer one (out-of-order loads)', async () => {
        const loadA = deferred();
        const loadB = deferred();
        getConsole.mockReturnValueOnce(loadA.promise).mockReturnValueOnce(loadB.promise);

        const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
        element.recordId = 'a01A';
        document.body.appendChild(element);
        element.recordId = 'a01B';

        loadB.resolve(consoleFor('a01B', '2026-11'));
        await flush();
        loadA.resolve(consoleFor('a01A', '2026-10'));
        await flush();

        expect(shownPeriods(element)).toEqual(['2026-11']);
    });

    it('shows nothing from the previous batch when the reload for the new record fails', async () => {
        getConsole.mockResolvedValueOnce(consoleFor('a01A', '2026-10'));
        const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
        element.recordId = 'a01A';
        document.body.appendChild(element);
        await flush();
        expect(shownPeriods(element)).toEqual(['2026-10']);

        getConsole.mockRejectedValueOnce({ body: { message: 'Insufficient access' } });
        element.recordId = 'a01B';
        await flush();

        expect(shownPeriods(element)).toEqual([]);
        expect(element.shadowRoot.textContent).toContain('Insufficient access');
    });

    it('refreshes the batch the action changed, even if the record changes before it finishes', async () => {
        getConsole.mockResolvedValue(consoleFor('a01A', '2026-10'));
        const paid = deferred();
        markPaid.mockReturnValueOnce(paid.promise);

        const element = createElement('c-pr-payout-console', { is: PrPayoutConsole });
        element.recordId = 'a01A';
        document.body.appendChild(element);
        await flush();

        const markPaidButton = [...element.shadowRoot.querySelectorAll('lightning-button')].find((b) => b.label === 'Mark paid');
        markPaidButton.dispatchEvent(new CustomEvent('click'));
        await flush();
        element.recordId = 'a01B';
        paid.resolve('Paid');
        await flush();
        await flush();

        expect(markPaid).toHaveBeenCalledWith({ batchId: 'a01A' });
        expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{ recordId: 'a01A' }]);
        expect(notifyRecordUpdateAvailable).not.toHaveBeenCalledWith([{ recordId: 'a01B' }]);
    });
});
