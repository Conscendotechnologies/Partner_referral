import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { openDashboardInFolder } from './support/groupA';

const DASHBOARD = 'Partner Commission – This Month';
const CHART = 'Commission per agency by status (AUD ex GST)';

test("S08-TC-03: Commission dashboard shows this month's Pending and Approved commission per agency in AUD", async ({ page }) => {
  test.setTimeout(300_000);
  let fiona = page;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Fiona Finance (PR test)"', async () => {
    fiona = await loginAs(page, 'Fiona', 'Finance (PR test)');
  });

  const dash = fiona.frameLocator('iframe[name^="sfxdash"]');

  await test.step('3-5. Open the Dashboards tab, the folder "Partner Referrals" and the dashboard "Partner Commission – This Month"', async () => {
    await openDashboardInFolder(fiona, 'Partner Referrals', DASHBOARD);
  });

  await test.step('Expected: amounts per agency are split into Pending and Approved and shown in AUD', async () => {
    const chart = dash.locator('article').filter({ has: dash.getByRole('heading', { name: CHART, exact: true }) });
    await expect(chart).toBeVisible({ timeout: 60_000 });
    // The chart has drawn once its bars (Agency, Status, AUD amount) are in the DOM.
    const bars = chart.getByRole('button', { name: /^Agency .+,Status (Pending|Approved),Sum of Amount \(ex GST\) \(AUD\) / });
    await expect(bars.first()).toBeAttached({ timeout: 60_000 });
    // The chart is drawn on a canvas; its "table equivalent" lists Agency, Status and the AUD amount per bar.
    await chart.locator('button.ng-assistiveText').dispatchEvent('click');
    const table = dash.getByRole('dialog', { name: /Table equivalent/ }).getByRole('table');
    await expect(table.getByRole('columnheader', { name: 'Agency', exact: true })).toBeAttached({ timeout: 30_000 });
    await expect(table.getByRole('columnheader', { name: 'Status', exact: true })).toBeAttached();
    await expect(table.getByRole('columnheader', { name: 'Sum of Amount (ex GST) (AUD)', exact: true })).toBeAttached();
    await expect(table.getByRole('rowheader', { name: 'Pending', exact: true }).first()).toBeAttached();
    await expect(table.getByRole('rowheader', { name: 'Approved', exact: true }).first()).toBeAttached();
    // Only those two statuses are listed.
    const statuses = await table.getByRole('rowheader', { name: /^(Draft|Pending|Approved|Paid|Rejected|Cancelled)$/ }).allInnerTexts();
    expect([...new Set(statuses.map((s) => s.trim()))].sort()).toEqual(['Approved', 'Pending']);
    for (const agency of ['Bayside Property Group', 'Harbour & Co Realty']) {
      await expect(table.getByRole('rowheader', { name: agency, exact: true }).first()).toBeAttached();
    }
    const amounts = await table.getByRole('cell').allInnerTexts();
    expect(amounts.length).toBeGreaterThan(0);
    for (const a of amounts) expect(a.trim()).toMatch(/^[\d,]+(\.\d+)?$/);
  });
});
