import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { fieldItem, openCommissionRow, openCommissionsRelatedList, openEditDialog, openFromListSettled } from './support/C';

// Precondition: S06-TC-02 has run in this run ("AI-TEST Commission QA" has its Partner Commission).
test('S12-TC-02: Commission page shows all its fields; Amount, Rate Applied and Services Connected are read-only', async ({ page }) => {
  let maya = page;

  await test.step('1-2. Setup > Users, Login as Maya Manager (PR test)', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  await test.step('3-4. Opportunities tab, search "AI-TEST Commission" and open the Opportunity', async () => {
    await openFromListSettled(maya, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
  });

  await test.step('5. Open the commission from the "Partner Commissions" related list', async () => {
    const grid = await openCommissionsRelatedList(maya);
    await openCommissionRow(maya, grid.getByRole('row').filter({ has: maya.getByRole('rowheader') }).first());
  });

  await test.step('Expected: the page shows all the commission fields', async () => {
    for (const label of [
      'Agency',
      'Opportunity',
      'Referral',
      'Rate Applied',
      'Services Connected',
      'Amount (ex GST)',
      'Status',
      'Approved By',
      'Approved On',
      'Cancellation Reason',
      'Reopened After Approval'
    ]) {
      await expect(fieldItem(maya, label), label).toBeVisible();
    }
  });

  await test.step('6. Click "Edit": Amount, Rate Applied and Services Connected cannot be edited', async () => {
    const dialog = await openEditDialog(maya);
    // An editable field (Status) proves the form has its inputs.
    await expect(dialog.getByRole('combobox', { name: 'Status' })).toBeEditable();
    for (const label of ['Amount (ex GST)', 'Rate Applied', 'Services Connected']) {
      await expect(dialog.getByRole('listitem').filter({ hasText: new RegExp(`^${label.replace(/[()]/g, '\\$&')}`) }), label).toBeVisible();
      await expect(dialog.getByRole('spinbutton', { name: label }), label).toHaveCount(0);
      await expect(dialog.getByRole('textbox', { name: label }), label).toHaveCount(0);
    }
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toBeHidden();
  });
});
