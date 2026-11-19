import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';
import { detailField, restoreAccountField } from './support/groupA';

const AGENCY = 'Bayside Property Group';
const ABN_ERROR = 'ABN must be exactly 11 digits.';

test('S01-TC-04: An ABN with fewer than 11 digits is rejected', async ({ page }) => {
  test.setTimeout(300_000);
  let maya = page;
  let abnBefore = '';

  await test.step('1-2. Open Setup > Users and click "Login" next to "Maya Manager (PR test)"', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  await test.step('3-4. Open the Accounts tab, search "Bayside Property Group" and open the Account', async () => {
    await openFromList(maya, 'Account', AGENCY, AGENCY);
    await expect(maya.locator('records-highlights2').getByText(AGENCY, { exact: true })).toBeVisible();
  });

  const dialog = maya.getByRole('dialog', { name: `Edit ${AGENCY}` });
  const abn = dialog.getByRole('textbox', { name: 'ABN', exact: true });

  await test.step('5. Click "Edit"', async () => {
    await maya.getByRole('button', { name: 'Edit', exact: true }).click();
    await expect(dialog.getByRole('textbox', { name: 'Account Name' })).toHaveValue(AGENCY, { timeout: 60_000 });
  });

  try {
    await test.step('6. Enter "1234567890" in "ABN"', async () => {
      await expect(abn).toBeVisible();
      abnBefore = await abn.inputValue();
      await abn.fill('1234567890');
      await expect(abn).toHaveValue('1234567890');
    });

    await test.step('7. Click "Save"', async () => {
      await dialog.getByRole('button', { name: 'Save', exact: true }).click();
    });

    await test.step('Expected: the error "ABN must be exactly 11 digits." is shown on the ABN field', async () => {
      // A field-level error sits in the ABN field's own form element.
      const abnElement = dialog.locator('lightning-input, records-record-layout-item').filter({ has: abn }).first();
      await expect(abnElement.getByText(ABN_ERROR)).toBeVisible({ timeout: 60_000 });
    });

    await test.step('Expected: the Account is not saved', async () => {
      await expect(dialog).toBeVisible();
      await expect(abn).toHaveValue('1234567890');
      await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
      await expect(dialog).toBeHidden();
      await maya.getByRole('tab', { name: 'Details' }).click();
      await expect(detailField(maya, 'ABN')).toContainText(abnBefore);
    });
  } finally {
    // Cleanup only: if the invalid ABN was wrongly saved, put the noted value back.
    if (abnBefore) {
      await restoreAccountField(maya, AGENCY, 'ABN', abnBefore, async (form) => {
        await form.getByRole('textbox', { name: 'ABN', exact: true }).fill(abnBefore);
      });
    }
  }
});
