import { test, expect } from './support/fixtures';
import { fieldValue, openCommissionRow, openCommissionsRelatedList, openEditDialog, saveErrors, openFromListSettled } from './support/C';

// Precondition: S06-TC-02 has run (the "AI-TEST Commission QA" Opportunity has its commission). Runs as the admin, as
// the case has no Login step; the admin can type into the read-only Amount, so the trigger is what refuses it.
test("S06-TC-09: Editing a commission's Amount is refused with a clear message", async ({ page }) => {
  let before = '';

  await test.step('1-2. Opportunities tab, search "AI-TEST Commission" and open the Opportunity', async () => {
    await openFromListSettled(page, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
  });

  await test.step('3. Open the commission from the "Partner Commissions" related list', async () => {
    const grid = await openCommissionsRelatedList(page);
    await openCommissionRow(page, grid.getByRole('row').filter({ has: page.getByRole('rowheader') }).first());
    await expect(fieldValue(page, 'Amount (ex GST)')).toHaveText(/^AUD [\d,]+\.\d{2}/);
    before = await fieldValue(page, 'Amount (ex GST)').innerText();
    expect(before).not.toMatch(/^AUD 1\.00\b/);
  });

  await test.step('4-6. Edit, change Amount to 1, Save', async () => {
    const dialog = await openEditDialog(page);
    const amount = dialog.getByRole('spinbutton', { name: 'Amount (ex GST)' });
    await expect(amount).toBeEditable();
    // fill() leaves the formatted value behind ("1501"), so select all, clear and type.
    await amount.click();
    await amount.press('Control+a');
    await amount.press('Backspace');
    await amount.pressSequentially('1');
    await expect(amount).toHaveValue('1');
    await dialog.getByRole('button', { name: 'Save', exact: true }).click();

    // Expected: the error is shown (in the form's "We hit a snag." error box) and the commission is not saved.
    const errors = saveErrors(page);
    await expect(
      errors.getByRole('listitem').filter({ hasText: /^Amount, rate, services, Opportunity and agency cannot be changed\. Cancel this commission and create a new one\.$/ })
    ).toBeVisible({ timeout: 60_000 });
    await errors.getByRole('button', { name: 'Close error dialog' }).click();
    await expect(dialog).toBeVisible();
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toBeHidden();
  });

  await test.step('Expected: the commission is not saved (Amount unchanged after a reload)', async () => {
    await page.reload();
    await expect(fieldValue(page, 'Amount (ex GST)')).toHaveText(before);
  });
});
