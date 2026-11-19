import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { openDashboardInFolder, refreshDashboard } from './support/groupA';

const DASHBOARD = 'Partner Referrals – SLA';

test('S08-TC-04: SLA dashboard lists uncontacted overdue Leads, late first contacts and moved-in referrals not connected', async ({ page }) => {
  test.setTimeout(300_000);
  let maya = page;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Maya Manager (PR test)"', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  const dash = maya.frameLocator('iframe[name^="sfxdash"]');

  await test.step('3-5. Open the Dashboards tab, the folder "Partner Referrals" and the dashboard "Partner Referrals – SLA"', async () => {
    await openDashboardInFolder(maya, 'Partner Referrals', DASHBOARD);
  });

  await test.step('6. Click "Refresh" and wait for the components to reload', async () => {
    await refreshDashboard(maya);
  });

  await test.step('Expected: a component for Leads past SLA Due At with no first contact', async () => {
    await expect(dash.getByRole('heading', { name: 'Past due, no first contact', exact: true })).toBeVisible();
  });

  await test.step('Expected: a component for Leads first contacted late', async () => {
    await expect(dash.getByRole('heading', { name: 'First contacted late', exact: true })).toBeVisible();
  });

  await test.step('Expected: a component for referrals whose move-in date has passed that are not Connected or Closed Lost', async () => {
    await expect(dash.getByRole('heading', { name: 'Moved in, not Connected or Closed Lost', exact: true })).toBeVisible();
  });
});
