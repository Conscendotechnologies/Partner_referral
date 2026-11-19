import { test, expect } from './support/fixtures';
import { runSuffix } from './support/salesforce';
import { detailField, fillReferralLead, recordTypeForm, saveNewLead } from './support/groupA';

test('S03-TC-01: A VIC Partner Referral Lead is routed to PR_VIC_TAS', async ({ page }) => {
  const lastName = `AI-TEST Route VIC ${runSuffix()}`;
  const newButton = page.getByRole('button', { name: 'New', exact: true }).first();
  const dialog = page.getByRole('dialog', { name: 'New Lead: Partner Referral' });

  await test.step('1. Open the Leads tab', async () => {
    await page.goto('/lightning/o/Lead/list');
    await expect(newButton).toBeVisible({ timeout: 60_000 });
  });

  await test.step('2. Click "New"', async () => {
    await newButton.click();
  });

  await test.step('3. Select record type "Partner Referral" and click "Next"', async () => {
    await recordTypeForm(page, 'Lead');
  });

  await test.step('4-8. Last Name, Company (if shown), State/Province "VIC", Move-in Date +30 days, Utilities "Electricity"', async () => {
    await fillReferralLead(dialog, { lastName, state: 'VIC', moveInDays: 30 });
  });

  await test.step('9. Click "Save"; Expected: the Lead is saved', async () => {
    await saveNewLead(page, dialog, lastName);
  });

  await test.step('Expected: Lead Owner is the queue "PR_VIC_TAS"', async () => {
    await page.getByRole('tab', { name: 'Details' }).click();
    await expect(detailField(page, 'Lead Owner')).toContainText('PR - VIC + TAS', { timeout: 60_000 });
  });
});
