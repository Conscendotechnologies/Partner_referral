import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';

// Read-only. The Payouts tab is granted only by PR_Finance, so for Maya Manager (PR test) the tab is not in the app and
// its page does not open: the three payout buttons are "not shown". The spec proves both before checking the buttons.
test('S07-TC-04: A user without Manage Partner Payouts cannot run, export or pay', async ({ page }) => {
  let maya = page;

  await test.step('1-2. Setup > Users, Login as Maya Manager (PR test)', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  await test.step('3. Open the "Payouts" tab in the Connectnow Partner Referrals app', async () => {
    await maya.goto('/lightning/app/c__PR_Partner_Referrals');
    await expect(maya.getByRole('heading', { name: 'Connectnow Partner Referrals', level: 1 })).toBeVisible({ timeout: 60_000 });
    const nav = maya.getByRole('navigation', { name: 'Global' });
    await expect(nav.getByRole('link', { name: 'Opportunities', exact: true })).toBeVisible({ timeout: 60_000 });
    await expect(nav.getByRole('link', { name: 'Partner Commissions', exact: true })).toBeVisible();
    // The tab is not in Maya's navigation, and its page does not open for her.
    await expect(nav.getByRole('link', { name: 'Payouts', exact: true })).toHaveCount(0);
    await maya.goto('/lightning/n/PR_Payouts');
    await expect(maya.getByRole('heading', { name: "Page doesn't exist", level: 1 })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: "Run payout", "Download Xero CSV" and "Mark paid" are not shown', async () => {
    await expect(maya.getByRole('heading', { name: 'Commission payouts' })).toHaveCount(0);
    for (const name of ['Run payout', 'Download Xero CSV', 'Mark paid']) {
      await expect(maya.getByRole('button', { name, exact: true }), name).toHaveCount(0);
    }
  });
});
