import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';
import { detailField, restoreAccountField, toast } from './support/groupA';

const AGENCY = 'Harbour & Co Realty';
const LOCKED = "Only Partner Managers can change an agency's partner status or commission rate.";

test("S01-TC-01: A sales rep cannot change an agency's Partner Status", async ({ page }) => {
  test.setTimeout(300_000);
  let sam = page;
  let editable = false;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Sam Rep (PR test)"', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3-4. Open the Accounts tab, search "Harbour & Co Realty" and open the Account', async () => {
    await openFromList(sam, 'Account', AGENCY, AGENCY);
    await expect(sam.locator('records-highlights2').getByText(AGENCY, { exact: true })).toBeVisible();
  });

  const dialog = sam.getByRole('dialog', { name: `Edit ${AGENCY}` });
  const status = dialog.getByRole('combobox', { name: 'Partner Status' });

  await test.step('5. Click "Edit"', async () => {
    await sam.getByRole('button', { name: 'Edit', exact: true }).click();
    // The form has loaded once its Account Name holds the record's name.
    await expect(dialog.getByRole('textbox', { name: 'Account Name' })).toHaveValue(AGENCY, { timeout: 60_000 });
    editable = (await status.count()) === 1 && (await status.isEnabled());
  });

  // If the field is editable and the save were wrongly accepted, put the agency back to Active (cleanup, not a check).
  try {
    await test.step('6. Select "Inactive" in "Partner Status" if the field is editable', async () => {
      test.info().annotations.push({ type: 'Partner Status on the edit form', description: editable ? 'editable' : 'missing or read-only' });
      if (editable) {
        await status.click();
        await dialog.getByRole('option', { name: 'Inactive', exact: true }).click();
        await expect(status).toHaveText(/Inactive/);
      }
    });

    await test.step('7. Click "Save"', async () => {
      await dialog.getByRole('button', { name: 'Save', exact: true }).click();
    });

    await test.step(`Expected: Partner Status cannot be changed (missing or read-only on the form, or the save fails with "${LOCKED}")`, async () => {
      // The expected result is itself an either/or: with an editable field the save must be refused.
      if (editable) {
        await expect(dialog.getByText(LOCKED)).toBeVisible({ timeout: 60_000 });
        await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
      } else {
        await expect(toast(sam)).toContainText(`Account "${AGENCY}" was saved`, { timeout: 60_000 });
      }
      await expect(dialog).toBeHidden({ timeout: 60_000 });
    });

    await test.step('Expected: after closing the form the Account still shows Partner Status "Active"', async () => {
      await sam.getByRole('tab', { name: 'Details' }).click();
      await expect(detailField(sam, 'Account Name')).toContainText(AGENCY, { timeout: 60_000 });
      await expect(detailField(sam, 'Partner Status')).toContainText('Active');
    });
  } finally {
    if (editable) {
      await restoreAccountField(sam, AGENCY, 'Partner Status', 'Active', async (form) => {
        await form.getByRole('combobox', { name: 'Partner Status' }).click();
        await form.getByRole('option', { name: 'Active', exact: true }).click();
      });
    }
  }
});
