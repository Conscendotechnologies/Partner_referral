import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { openDashboardInFolder, refreshDashboard } from './support/groupA';

const DASHBOARD = 'Partner Referrals – Volume';
const WEEK = 'Referrals per agency per week (last 90 days)';
const MONTH = 'Referrals per agency this month, by status';

test('S08-TC-01: Volume dashboard shows referrals per agency per week and per month', async ({ page }) => {
  test.setTimeout(300_000);
  let maya = page;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Maya Manager (PR test)"', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  const dash = maya.frameLocator('iframe[name^="sfxdash"]');

  await test.step('3-5. Open the Dashboards tab, the folder "Partner Referrals" and the dashboard "Partner Referrals – Volume"', async () => {
    await openDashboardInFolder(maya, 'Partner Referrals', DASHBOARD);
  });

  await test.step('6. Click "Refresh" and wait for the components to reload', async () => {
    await refreshDashboard(maya);
  });

  const component = (title: string) => dash.locator('article').filter({ has: dash.getByRole('heading', { name: title, exact: true }) });
  // Each chart has a "table equivalent" dialog listing its rows; the agencies are its row headers.
  const tableOf = async (title: string) => {
    await component(title).locator('button.ng-assistiveText').dispatchEvent('click');
    const dialog = dash.getByRole('dialog', { name: /Table equivalent/ });
    await expect(dialog).toBeAttached({ timeout: 30_000 });
    return dialog;
  };
  const closeTable = async () => {
    await dash.getByRole('dialog', { name: /Table equivalent/ }).press('Escape');
    await expect(dash.getByRole('dialog', { name: /Table equivalent/ })).toHaveCount(0);
  };

  await test.step('Expected: a component shows referrals per agency per week (both agencies listed)', async () => {
    await expect(component(WEEK)).toBeVisible();
    await expect(
      component(WEEK)
        .getByRole('button', { name: /^Referring Agency .*Created Date/ })
        .first()
    ).toBeAttached();
    const table = await tableOf(WEEK);
    await expect(table.getByRole('rowheader', { name: 'Harbour & Co Realty' }).first()).toBeAttached();
    await expect(table.getByRole('rowheader', { name: 'Bayside Property Group' }).first()).toBeAttached();
    await closeTable();
  });

  await test.step('Expected: a component shows referrals per agency this month', async () => {
    await expect(component(MONTH)).toBeVisible();
    await expect(
      component(MONTH)
        .getByRole('button', { name: /^Referring Agency .*Status/ })
        .first()
    ).toBeAttached();
  });

  await test.step('Expected: Harbour & Co Realty and Bayside Property Group both appear', async () => {
    const table = await tableOf(MONTH);
    await expect(table.getByRole('rowheader', { name: 'Harbour & Co Realty' }).first()).toBeAttached();
    await expect(table.getByRole('rowheader', { name: 'Bayside Property Group' }).first()).toBeAttached();
  });
});
