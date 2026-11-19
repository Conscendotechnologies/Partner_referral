import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { openApp } from './support/groupA';

// Precondition: PR 8 (D4) adds the "Referral Queue" tab (prQueueLeads: a lightning-datatable with the columns Name,
// Urgent, Move-in Date, State, Status, First Contact Due, SLA Breached, Referring Agency, Queue).
const SAM_QUEUES = ['PR - NSW + ACT', 'PR - VIC + TAS'];

test("S03-TC-11: The rep's Referral Queue puts urgent Leads first, then by move-in date", async ({ page }) => {
  test.setTimeout(300_000);
  let sam = page;
  type Row = { queue: string; urgent: boolean; moveIn: number };
  let rows: Row[] = [];

  await test.step('1-2. Open Setup > Users and click "Login" next to "Sam Rep (PR test)"', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3. Open the app "Connectnow Partner Referrals" and click the "Referral Queue" tab', async () => {
    await openApp(sam, 'Connectnow Partner Referrals');
    await sam.getByRole('navigation', { name: 'Global' }).getByRole('link', { name: 'Referral Queue', exact: true }).click();
    const card = sam.locator('c-pr-queue-leads');
    await expect(card.getByText('My partner referral queue')).toBeVisible({ timeout: 60_000 });
    const table = card.getByRole('grid');
    await expect(table.getByRole('row').nth(1)).toBeVisible({ timeout: 60_000 });
    const cells = card.locator('tbody tr');
    const count = await cells.count();
    for (let i = 0; i < count; i++) {
      const tr = cells.nth(i);
      const queue = (await tr.locator('[data-label="Queue"]').innerText()).trim();
      // A true boolean cell shows a check icon; a false one is empty.
      const urgent = (await tr.locator('[data-label="Urgent"] svg').count()) > 0;
      const moveInText = (await tr.locator('[data-label="Move-in Date"]').innerText()).trim();
      rows.push({ queue, urgent, moveIn: moveInText ? Date.parse(moveInText) : Number.POSITIVE_INFINITY });
    }
    expect(rows.length).toBeGreaterThan(0);
  });

  await test.step("Expected: only Leads from Sam's queues (PR - NSW + ACT and PR - VIC + TAS) are listed", async () => {
    expect(rows.filter((r) => !SAM_QUEUES.includes(r.queue))).toEqual([]);
  });

  await test.step('Expected: all Leads with Urgent ticked appear above the non-urgent Leads', async () => {
    const urgentFlags = rows.map((r) => r.urgent);
    expect(urgentFlags, 'the queue has at least one urgent Lead to order').toContain(true);
    expect(urgentFlags).toEqual([...urgentFlags].sort((a, b) => Number(b) - Number(a)));
  });

  await test.step('Expected: within each group Leads are ordered by Move-in Date, earliest first', async () => {
    for (const group of [rows.filter((r) => r.urgent), rows.filter((r) => !r.urgent)]) {
      const dates = group.map((r) => r.moveIn);
      expect(dates).toEqual([...dates].sort((a, b) => a - b));
    }
  });
});
