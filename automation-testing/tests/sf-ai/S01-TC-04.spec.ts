import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';
import { detailField, replaceValue, restoreAccountField } from './support/groupA';

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
  // After a refused save, the "We hit a snag." popover is the only dialog: the edit form is hidden from the
  // accessibility tree until the popover is closed.
  const snag = maya.getByRole('dialog', { name: 'We hit a snag.' });

  await test.step('5. Click "Edit"', async () => {
    await maya.getByRole('button', { name: 'Edit', exact: true }).click();
    await expect(dialog.getByRole('textbox', { name: 'Account Name' })).toHaveValue(AGENCY, { timeout: 60_000 });
  });

  try {
    await test.step('6. Enter "1234567890" in "ABN"', async () => {
      await expect(abn).toBeVisible();
      abnBefore = await abn.inputValue();
      await replaceValue(abn, '1234567890');
      await expect(abn).toHaveValue('1234567890');
    });

    await test.step('7. Click "Save"', async () => {
      await dialog.getByRole('button', { name: 'Save', exact: true }).click();
    });

    await test.step('Expected: the error "ABN must be exactly 11 digits." is shown on the ABN field', async () => {
      // The "We hit a snag." popover names ABN as the field in error. While it is open the edit form is hidden from the
      // accessibility tree, so the field itself is read after the popover is closed: its message is tied to the ABN
      // input (aria-describedby), i.e. it is that textbox's accessible description.
      await expect(snag).toBeVisible({ timeout: 60_000 });
      await expect(snag.getByRole('listitem').filter({ hasText: /^ABN$/ })).toHaveCount(1);
      await snag.getByRole('button', { name: 'Close error dialog' }).click();
      await expect(dialog).toBeVisible();
      await expect(abn).toHaveAccessibleDescription(new RegExp(ABN_ERROR.replace(/\./g, '\\.')));
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
        await replaceValue(form.getByRole('textbox', { name: 'ABN', exact: true }), abnBefore);
      });
    }
  }
});
