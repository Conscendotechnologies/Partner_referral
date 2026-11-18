import { createElement } from 'lwc';
import PrQueueLeads from 'c/prQueueLeads';
import getQueueLeads from '@salesforce/apex/PR_QueueLeadsController.getQueueLeads';

jest.mock('@salesforce/apex/PR_QueueLeadsController.getQueueLeads', () => ({ default: jest.fn() }), { virtual: true });

/** Lets the mocked Apex promise and the re-render settle. */
const flush = async () => {
    for (let i = 0; i < 5; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
};

const ROWS = [
    { id: '00Q000000000001', name: 'Urgent Mover', urgent: true, moveInDate: '2026-11-20', queue: 'PR - QLD' },
    { id: '00Q000000000002', name: 'Soon Mover', urgent: false, moveInDate: '2026-11-29', queue: 'PR - QLD' },
    { id: '00Q000000000003', name: 'Later Mover', urgent: false, moveInDate: '2026-12-19', queue: 'PR - QLD' }
];

function mount() {
    const element = createElement('c-pr-queue-leads', { is: PrQueueLeads });
    document.body.appendChild(element);
    return element;
}

describe('c-pr-queue-leads', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
    });

    it('shows the rows in the order the server returns (urgent first, then move-in date)', async () => {
        getQueueLeads.mockResolvedValue({ rows: ROWS, hasMore: false, rowLimit: 500 });
        const element = mount();
        await flush();
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data.map((r) => r.name)).toEqual(['Urgent Mover', 'Soon Mover', 'Later Mover']);
        expect(table.data[0].url).toBe('/00Q000000000001');
        expect(element.shadowRoot.querySelector('.count').textContent).toBe('3 open, 1 urgent');
    });

    it('says so when the queues are empty', async () => {
        getQueueLeads.mockResolvedValue({ rows: [], hasMore: false, rowLimit: 500 });
        const element = mount();
        await flush();
        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        expect(element.shadowRoot.querySelector('.empty')).not.toBeNull();
    });

    it('says when the list is cut at the row limit', async () => {
        getQueueLeads.mockResolvedValue({ rows: ROWS.slice(0, 2), hasMore: true, rowLimit: 2 });
        const element = mount();
        await flush();
        expect(element.shadowRoot.querySelector('.partial').textContent).toContain('cut at 2 Leads');
        expect(element.shadowRoot.querySelector('.count').textContent).toBe(
            'Showing the first 2 open (1 urgent); more are in your queues'
        );
    });

    it('shows the server error', async () => {
        getQueueLeads.mockRejectedValue({ body: { message: 'No access' } });
        const element = mount();
        await flush();
        expect(element.shadowRoot.querySelector('.error').textContent).toBe('No access');
    });

    it('reloads on Refresh', async () => {
        getQueueLeads.mockResolvedValue({ rows: ROWS, hasMore: false, rowLimit: 500 });
        const element = mount();
        await flush();
        element.shadowRoot.querySelector('lightning-button').click();
        await flush();
        expect(getQueueLeads).toHaveBeenCalledTimes(2);
    });
});
