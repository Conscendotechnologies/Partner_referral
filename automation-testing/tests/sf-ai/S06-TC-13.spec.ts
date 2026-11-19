import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { choosePicklist, fieldValue, openCommissionRow, openCommissionsRelatedList, openEditDialog, saveErrors, openFromListSettled } from './support/C';

// Precondition: S06-TC-10 has run (the commission on "AI-TEST Commission QA" is Approved). Blocked by D2 until PR #8.
test('S06-TC-13: Partner Manager is refused when moving an Approved commission back to Pending', async ({ page }) => {
  let maya = page;

  await test.step('1-2. Setup > Users, Login as Maya Manager (PR test)', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  await test.step('3-4. Opportunities tab, search "AI-TEST Commission" and open the Opportunity', async () => {
    await openFromListSettled(maya, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
  });

  await test.step('5. Open the Approved commission from the "Partner Commissions" related list', async () => {
    const grid = await openCommissionsRelatedList(maya);
    const approved = grid.getByRole('row').filter({ has: maya.getByRole('gridcell', { name: 'Approved', exact: true }) });
    await expect(approved).toHaveCount(1);
    await openCommissionRow(maya, approved);
    await expect(fieldValue(maya, 'Status')).toHaveText('Approved');
  });

  await test.step('6. Change Status to "Pending" and save', async () => {
    const dialog = await openEditDialog(maya);
    await choosePicklist(dialog, 'Status', 'Pending');
    await dialog.getByRole('button', { name: 'Save', exact: true }).click();

    // Expected: the error is shown and the commission is not saved.
    const errors = saveErrors(maya);
    await expect(
      errors.getByRole('listitem').filter({ hasText: /^Only Finance can move an approved commission back to Pending\.$/ })
    ).toBeVisible({ timeout: 60_000 });
    await errors.getByRole('button', { name: 'Close error dialog' }).click();
    await expect(dialog).toBeVisible();
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toBeHidden();
  });

  await test.step('Expected: the commission is not saved (still Approved after a reload)', async () => {
    await maya.reload();
    await expect(fieldValue(maya, 'Status')).toHaveText('Approved');
  });
});
