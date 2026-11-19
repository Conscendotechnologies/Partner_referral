import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { openDashboardInFolder, refreshDashboard } from './support/groupA';

const DASHBOARD = 'Partner Referrals – Conversion';
const TABLE = 'Referrals in vs Connected per agency';
const AGENCIES = ['Bayside Property Group', 'Harbour & Co Realty'];

test('S08-TC-02: Conversion dashboard shows referrals in vs Connected per agency with the rate', async ({ page }) => {
  test.setTimeout(300_000);
  let maya = page;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Maya Manager (PR test)"', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  const dash = maya.frameLocator('iframe[name^="sfxdash"]');

  await test.step('3-5. Open the Dashboards tab, the folder "Partner Referrals" and the dashboard "Partner Referrals – Conversion"', async () => {
    await openDashboardInFolder(maya, 'Partner Referrals', DASHBOARD);
  });

  await test.step('6. Click "Refresh" and wait for the components to reload', async () => {
    await refreshDashboard(maya);
  });

  await test.step('Expected: each agency shows the number of referrals, the number Connected and a conversion rate percentage', async () => {
    const table = dash
      .locator('article')
      .filter({ has: dash.getByRole('heading', { name: TABLE, exact: true }) })
      .getByRole('grid');
    await expect(table.getByRole('columnheader', { name: /^Record Count/ })).toBeVisible({ timeout: 60_000 });
    await expect(table.getByRole('columnheader', { name: /^Sum of Connected/ })).toBeVisible();
    await expect(table.getByRole('columnheader', { name: /Conversion rate/ })).toBeVisible();
    for (const agency of AGENCIES) {
      const row = table.getByRole('row').filter({ has: dash.getByRole('rowheader', { name: `Referring Agency: ${agency}`, exact: true }) });
      await expect(row).toHaveCount(1);
      const referrals = row.getByRole('gridcell', { name: /^Record Count: \d+$/ });
      const connected = row.getByRole('gridcell', { name: /^Sum of Connected: \d+$/ });
      const rate = row.getByRole('gridcell', { name: /^Conversion rate: \d+(\.\d+)?%$/ });
      await expect(referrals).toBeVisible();
      await expect(connected).toBeVisible();
      await expect(rate).toBeVisible();
      // The rate is Connected / referrals.
      const n = Number(await referrals.innerText());
      const c = Number(await connected.innerText());
      const r = Number((await rate.innerText()).replace('%', ''));
      expect(n, `${agency} has referrals`).toBeGreaterThan(0);
      expect(r).toBeCloseTo((c / n) * 100, 0);
    }
  });
});
