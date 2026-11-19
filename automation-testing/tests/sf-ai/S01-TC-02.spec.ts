import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';
import { detailField, replaceValue, restoreAccountField, toast } from './support/groupA';

const AGENCY = 'Harbour & Co Realty';
const LOCKED = "Only Partner Managers can change an agency's partner status or commission rate.";

// Runs as Sam (a sales rep), never as the admin. If the field were editable and the save wrongly accepted, the
// cleanup puts the original rate back, so the case can never leave the real agency changed.
test("S01-TC-02: A sales rep cannot change an agency's Commission Rate", async ({ page }) => {
  test.setTimeout(300_000);
  let sam = page;
  let editable = false;
  let rateBefore = '';
  // The rate as the edit form shows it, read before the case types into it: what cleanup puts back.
  let formRate = '';

  await test.step('1-2. Open Setup > Users and click "Login" next to "Sam Rep (PR test)"', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3-4. Open the Accounts tab, search "Harbour & Co Realty" and open the Account', async () => {
    await openFromList(sam, 'Account', AGENCY, AGENCY);
    await sam.getByRole('tab', { name: 'Details' }).click();
    await expect(detailField(sam, 'Account Name')).toContainText(AGENCY, { timeout: 60_000 });
    // Noted for "the Account's Commission Rate is unchanged"; the check itself is the last step.
    const rate = detailField(sam, 'Commission Rate');
    if ((await rate.count()) === 1) rateBefore = (await rate.innerText()).replace('Commission Rate', '').trim();
  });

  const dialog = sam.getByRole('dialog', { name: `Edit ${AGENCY}` });
  const rateInput = dialog.getByRole('textbox', { name: 'Commission Rate' }).or(dialog.getByRole('spinbutton', { name: 'Commission Rate' }));

  await test.step('5. Click "Edit"', async () => {
    await sam.getByRole('button', { name: 'Edit', exact: true }).click();
    await expect(dialog.getByRole('textbox', { name: 'Account Name' })).toHaveValue(AGENCY, { timeout: 60_000 });
    editable = (await rateInput.count()) === 1 && (await rateInput.isEditable());
    if (editable) {
      formRate = (await rateInput.inputValue()).trim();
      expect(formRate, 'the original Commission Rate is readable before it is changed').toMatch(/\d/);
    }
  });

  try {
    await test.step('6. Enter "65" in "Commission Rate" if the field is editable', async () => {
      test.info().annotations.push({ type: 'Commission Rate on the edit form', description: editable ? 'editable' : 'missing or read-only' });
      if (editable) {
        await replaceValue(rateInput, '65');
        await expect(rateInput).toHaveValue(/^65/);
      }
    });

    await test.step('7. Click "Save"', async () => {
      await dialog.getByRole('button', { name: 'Save', exact: true }).click();
    });

    await test.step(`Expected: Commission Rate cannot be changed (missing or read-only on the form, or the save fails with "${LOCKED}")`, async () => {
      // The expected result is itself an either/or: with an editable field the save must be refused.
      if (editable) {
        await expect(dialog.getByText(LOCKED)).toBeVisible({ timeout: 60_000 });
        await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
      } else {
        await expect(toast(sam)).toContainText(`Account "${AGENCY}" was saved`, { timeout: 60_000 });
      }
      await expect(dialog).toBeHidden({ timeout: 60_000 });
    });

    await test.step("Expected: after closing the form the Account's Commission Rate is unchanged", async () => {
      await sam.getByRole('tab', { name: 'Details' }).click();
      await expect(detailField(sam, 'Account Name')).toContainText(AGENCY, { timeout: 60_000 });
      await expect(detailField(sam, 'Commission Rate')).toBeVisible();
      expect(rateBefore, 'Commission Rate was shown before the edit').not.toBe('');
      await expect(detailField(sam, 'Commission Rate')).toContainText(rateBefore);
    });
  } finally {
    if (editable && formRate) {
      const original = formRate.replace(/[^\d.]/g, '');
      await restoreAccountField(sam, AGENCY, 'Commission Rate', original, async (form) => {
        await replaceValue(
          form.getByRole('textbox', { name: 'Commission Rate' }).or(form.getByRole('spinbutton', { name: 'Commission Rate' })),
          original
        );
      });
    }
  }
});
