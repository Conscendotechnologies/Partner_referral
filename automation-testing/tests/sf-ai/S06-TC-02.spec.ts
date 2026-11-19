import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { choosePicklist, fieldValue, logOutAs, openCommissionRow, openCommissionsRelatedList, openEditDialog, savedToast, openFromListSettled } from './support/C';

// Precondition: node scripts/qa-data.mjs <org> commissions (seeds "AI-TEST Commission QA" at Connection Requested with
// 3 products). This case moves it on, so the reset has to run again before the next attempt.
test('S06-TC-02: Moving an Opportunity to Utilities Connected shows a Pending commission', async ({ page }) => {
  let sam = page;
  let maya = page;

  await test.step('1-2. Setup > Users, Login as Sam Rep (PR test)', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3-4. Opportunities tab, search "AI-TEST Commission" and open the Opportunity', async () => {
    await openFromListSettled(sam, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
    await expect(fieldValue(sam, 'Stage')).toHaveText('Connection Requested');
  });

  await test.step('5. Change Stage to "Utilities Connected" and save', async () => {
    const dialog = await openEditDialog(sam);
    await choosePicklist(dialog, 'Stage', 'Utilities Connected');
    await dialog.getByRole('button', { name: 'Save', exact: true }).click();
    await expect(savedToast(sam, /^Opportunity "AI-TEST Commission QA" was saved\.$/)).toBeVisible({ timeout: 60_000 });
    await expect(dialog).toBeHidden();
    await expect(fieldValue(sam, 'Stage')).toHaveText('Utilities Connected');
  });

  await test.step('6. Log out as Sam, then Login as Maya Manager (PR test)', async () => {
    await logOutAs(sam, 'Sam Rep (PR test)');
    maya = await loginAs(sam, 'Maya', 'Manager (PR test)');
  });

  await test.step('7-8. Open the Opportunity, its "Partner Commissions" related list and the commission', async () => {
    await openFromListSettled(maya, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
    // Expected: exactly one commission, Status "Pending".
    await expect(maya.getByRole('link', { name: /^Partner Commissions \(\d+\)$/ })).toHaveText(/^Partner Commissions\s\(1\)$/);
    const grid = await openCommissionsRelatedList(maya);
    const rows = grid.getByRole('row').filter({ has: maya.getByRole('rowheader') });
    await expect(rows).toHaveCount(1);
    await expect(rows.getByRole('gridcell', { name: 'Pending', exact: true })).toBeVisible();
    await openCommissionRow(maya, rows.first());
  });

  await test.step('Expected: Pending, Services 3, Rate Applied R, Amount 3 x R, agency Harbour & Co Realty', async () => {
    await expect(fieldValue(maya, 'Status')).toHaveText('Pending');
    await expect(fieldValue(maya, 'Services Connected')).toHaveText('3');
    await expect(fieldValue(maya, 'Agency').getByRole('link')).toHaveText('Harbour & Co Realty');
    // R is the agency's Commission Rate, as the commission stamped it (D3: the Account page has no Commission Rate yet).
    const rate = fieldValue(maya, 'Rate Applied');
    await expect(rate).toHaveText(/^AUD [\d,]+\.\d{2}\b/);
    const r = Number((await rate.innerText()).match(/^AUD ([\d,]+\.\d{2})/)![1].replace(/,/g, ''));
    expect(r).toBeGreaterThan(0);
    const amount = (3 * r).toLocaleString('en-AU', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    await expect(fieldValue(maya, 'Amount (ex GST)')).toHaveText(new RegExp(`^AUD ${amount.replace(/[.,]/g, '\\$&')}(\\s|$)`));
  });
});
