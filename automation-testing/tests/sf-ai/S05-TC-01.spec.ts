import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { fieldValue, openFromListSettled } from './support/C';

// Precondition: node scripts/qa-data.mjs <org> commissions seeds the Lead "AI-TEST Convert QA" (Working, NSW,
// Electricity + Internet, no Company, owned by Sam Rep (PR test)).
// Known defect D1 (fixed by PR #8): Sam's conversion fails with "Unable to find default record type".
test('S05-TC-01: Converting a Partner Referral Lead creates a Person Account and a Partner Referral Opportunity at Qualification', async ({ page }) => {
  let sam = page;

  await test.step('1-2. Setup > Users, Login as Sam Rep (PR test)', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3-4. Leads tab, search "AI-TEST Convert" and open the Lead', async () => {
    await openFromListSettled(sam, 'Lead', 'AI-TEST Convert', 'AI-TEST Convert QA');
    await expect(sam.getByRole('heading', { level: 1, name: 'AI-TEST Convert QA' })).toBeVisible();
  });

  await test.step('5-6. Click "Convert", keep "Create New" for Account and Opportunity and click "Convert"', async () => {
    await sam.getByRole('button', { name: 'Convert', exact: true }).click();
    const dialog = sam.getByRole('dialog', { name: 'Convert Lead' });
    await expect(dialog.getByRole('button', { name: 'Convert', exact: true })).toBeEnabled({ timeout: 60_000 });
    // Keep "Create New" (the default) for both, and an Opportunity is created.
    await expect(dialog.getByRole('radio', { name: 'Create New Account' })).toBeChecked();
    await expect(dialog.getByRole('radio', { name: 'Create New Opportunity' })).toBeChecked();
    await expect(dialog.getByRole('checkbox', { name: "Don't create an opportunity upon conversion checkbox" })).not.toBeChecked();
    await dialog.getByRole('button', { name: 'Convert', exact: true }).click();
    // Before #8 (D1) the dialog stayed open with the alert "Unable to find default record type".
    await expect(sam.getByRole('dialog', { name: 'Your lead has been converted' })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('7. Click the new Opportunity link', async () => {
    const converted = sam.getByRole('dialog', { name: 'Your lead has been converted' });
    // The Opportunity card's record link (Opportunity URLs start with the 006 key prefix).
    await converted.locator('a[href*="/006"]').first().click();
    await expect(sam).toHaveURL(/\/lightning\/r\/(Opportunity\/)?006/, { timeout: 60_000 });
    await expect(fieldValue(sam, 'Stage')).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: record type Partner Referral, Stage Qualification, price book Partner Referral Utilities', async () => {
    await expect(fieldValue(sam, 'Opportunity Record Type')).toHaveText(/^Partner Referral(Change Record Type)?$/);
    await expect(fieldValue(sam, 'Stage')).toHaveText('Qualification');
    // A lookup's value also holds its hover-card button text ("Preview"), as the record type holds "Change Record Type".
    await expect(fieldValue(sam, 'Price Book')).toHaveText(/^Partner Referral Utilities(Preview)?$/);
  });

  await test.step('Expected: the Account created is a Person Account named after the mover', async () => {
    const account = fieldValue(sam, 'Account Name').getByRole('link', { name: 'AI-TEST Convert QA', exact: true });
    await expect(account).toBeVisible();
    await account.click();
    await expect(sam).toHaveURL(/\/lightning\/r\/Account\//, { timeout: 60_000 });
    const header = sam.locator('records-highlights2:visible');
    await expect(header.getByText('Person Account', { exact: true })).toBeVisible({ timeout: 60_000 });
    await expect(header.getByRole('heading', { level: 1 })).toHaveText('AI-TEST Convert QA');
  });
});
