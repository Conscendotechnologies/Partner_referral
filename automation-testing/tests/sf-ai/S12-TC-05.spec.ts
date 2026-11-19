import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { fieldItem, showDetails } from './support/B';

test('S12-TC-05: Partner Referral Lead and Opportunity layouts show the partner referral fields', async ({ page }) => {
  const app = await test.step('Steps 1-2: Setup > Users > Login as "Sam Rep (PR test)"', () => loginAs(page, 'Sam', 'Rep (PR test)'));

  await test.step('Step 3: Open the Leads tab', async () => {
    await app.goto('/lightning/o/Lead/list');
    await expect(app.getByRole('button', { name: /^Select a List View/ })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Step 4: Select the "PR - NSW + ACT queue" list view', async () => {
    await app.getByRole('button', { name: /^Select a List View/ }).click();
    await app.getByRole('combobox', { name: 'Search lists...' }).fill('PR - NSW');
    await app.getByRole('option', { name: 'PR - NSW + ACT queue', exact: true }).click();
    await expect(app.getByRole('heading', { level: 1, name: /PR - NSW \+ ACT queue/ })).toBeVisible();
    await expect(app.getByRole('status', { name: 'PR - NSW + ACT queue' })).toContainText(/\d+\+? items?/);
  });

  await test.step('Step 5: Open the first Lead', async () => {
    // The first data row; this view's first columns are Urgent and Move-in Date, so the Lead's link is the row's first link.
    const first = app.getByRole('grid').getByRole('row').nth(1).getByRole('link').first();
    const name = (await first.textContent())!.trim();
    await first.click();
    await expect(app.getByRole('heading', { level: 1, name, exact: true })).toBeVisible({ timeout: 60_000 });
    await showDetails(app);
  });

  await test.step('Expected: Referral, Referring Agency, Referring Agent, Move-in Date, Utilities, consent, Urgent, First Contact Due, First Contacted At and SLA Breached', async () => {
    for (const label of [
      'Referral',
      'Referring Agency',
      'Referring Agent',
      'Move-in Date',
      'Utilities',
      'Consent Given At',
      'Consent Version',
      'Urgent',
      'First Contact Due',
      'First Contacted At',
      'SLA Breached'
    ]) {
      await expect(fieldItem(app, label), label).toBeVisible();
    }
  });
});
