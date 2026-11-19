import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';
import { detailField, restoreAccountField, toast } from './support/groupA';

const AGENCY = 'Bayside Property Group';

// Precondition: "Note the current Commission Rate of Bayside Property Group and set it back after the case". The
// rate is noted from the Details before the edit and put back at the end (also when a check fails).
test("S01-TC-03: A Partner Manager can change an agency's Commission Rate", async ({ page }) => {
  test.setTimeout(300_000);
  let maya = page;
  let rateBefore = '';
  let saved = false;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Maya Manager (PR test)"', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  await test.step('3-4. Open the Accounts tab, search "Bayside Property Group" and open the Account', async () => {
    await openFromList(maya, 'Account', AGENCY, AGENCY);
    await maya.getByRole('tab', { name: 'Details' }).click();
    await expect(detailField(maya, 'Account Name')).toContainText(AGENCY, { timeout: 60_000 });
  });

  await test.step('Precondition: note the current Commission Rate', async () => {
    const rate = detailField(maya, 'Commission Rate');
    await expect(rate).toBeVisible();
    rateBefore = (await rate.innerText()).replace('Commission Rate', '').trim();
    expect(rateBefore).toMatch(/\d/);
  });

  const dialog = maya.getByRole('dialog', { name: `Edit ${AGENCY}` });
  const rateInput = dialog.getByRole('textbox', { name: 'Commission Rate' }).or(dialog.getByRole('spinbutton', { name: 'Commission Rate' }));

  try {
    await test.step('5. Click "Edit"', async () => {
      await maya.getByRole('button', { name: 'Edit', exact: true }).click();
      await expect(dialog.getByRole('textbox', { name: 'Account Name' })).toHaveValue(AGENCY, { timeout: 60_000 });
    });

    await test.step('6. Enter "61" in "Commission Rate"', async () => {
      await rateInput.fill('61');
      await expect(rateInput).toHaveValue(/^61/);
    });

    await test.step('7. Click "Save"; Expected: the Account is saved without an error', async () => {
      await dialog.getByRole('button', { name: 'Save', exact: true }).click();
      await expect(toast(maya)).toContainText(`Account "${AGENCY}" was saved`, { timeout: 60_000 });
      saved = true;
      await expect(dialog).toBeHidden();
    });

    await test.step('Expected: the detail page shows Commission Rate 61', async () => {
      await expect(detailField(maya, 'Commission Rate')).toContainText(/\b61(\.00)?\b/);
    });
  } finally {
    if (saved) {
      const original = rateBefore.replace(/[^\d.]/g, '');
      await restoreAccountField(maya, AGENCY, 'Commission Rate', rateBefore, async (form) => {
        await form
          .getByRole('textbox', { name: 'Commission Rate' })
          .or(form.getByRole('spinbutton', { name: 'Commission Rate' }))
          .fill(original);
      });
    }
  }
});
