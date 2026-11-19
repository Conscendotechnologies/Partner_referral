import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { choosePicklist, fieldValue, openCommissionRow, openCommissionsRelatedList, openEditDialog, savedToast, todayAU, openFromListSettled } from './support/C';

// Precondition: S06-TC-02 has run (a Pending commission on "AI-TEST Commission QA").
// Known defect D2 (fixed by PR #8): the save fails with "insufficient privileges", as the commission is owned by the rep.
test('S06-TC-10: A Partner Manager approves a Pending commission and Approved By / On are stamped', async ({ page }) => {
  let maya = page;

  await test.step('1-2. Setup > Users, Login as Maya Manager (PR test)', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  await test.step('3-4. Opportunities tab, search "AI-TEST Commission" and open the Opportunity', async () => {
    await openFromListSettled(maya, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
  });

  await test.step('5. Open the commission from the "Partner Commissions" related list', async () => {
    const grid = await openCommissionsRelatedList(maya);
    const pending = grid.getByRole('row').filter({ has: maya.getByRole('gridcell', { name: 'Pending', exact: true }) });
    await expect(pending).toHaveCount(1);
    await openCommissionRow(maya, pending);
    await expect(fieldValue(maya, 'Status')).toHaveText('Pending');
  });

  await test.step('6. Change Status to "Approved" and save', async () => {
    const dialog = await openEditDialog(maya);
    await choosePicklist(dialog, 'Status', 'Approved');
    await dialog.getByRole('button', { name: 'Save', exact: true }).click();
    // D2: instead of this toast, a "We hit a snag." dialog says "you don't have the necessary privileges to edit this record".
    await expect(savedToast(maya, /^Partner Commission "COM-\d+" was saved\.$/)).toBeVisible({ timeout: 60_000 });
    await expect(dialog).toBeHidden();
  });

  await test.step('Expected: Status Approved, Approved By Maya Manager (PR test), Approved On today', async () => {
    await expect(fieldValue(maya, 'Status')).toHaveText('Approved');
    await expect(fieldValue(maya, 'Approved By').getByRole('link')).toHaveText('Maya Manager (PR test)');
    await expect(fieldValue(maya, 'Approved On')).toHaveText(new RegExp(`^${todayAU()}`));
  });
});
