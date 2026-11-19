import { test, expect } from './support/fixtures';
import { recordTypeForm } from './support/groupA';

test('S00-TC-02: Partner Referral Lead offers only the 5 programme statuses and Lead Source "Partner Referral"', async ({ page }) => {
  const newButton = page.getByRole('button', { name: 'New', exact: true }).first();
  const dialog = page.getByRole('dialog', { name: 'New Lead: Partner Referral' });
  let statusOptions: string[] = [];

  await test.step('1. Open the Leads tab', async () => {
    await page.goto('/lightning/o/Lead/list');
    await expect(newButton).toBeVisible({ timeout: 60_000 });
  });

  await test.step('2. Click "New"', async () => {
    await newButton.click();
  });

  await test.step('3. Select record type "Partner Referral" and click "Next"', async () => {
    await recordTypeForm(page, 'Lead');
  });

  await test.step('4. Open the "Lead Status" picklist', async () => {
    await dialog.getByRole('combobox', { name: 'Lead Status' }).click();
    const listbox = dialog.getByRole('listbox', { name: 'Lead Status' });
    await expect(listbox.getByRole('option', { name: 'New', exact: true })).toBeVisible();
    statusOptions = (await listbox.getByRole('option').allInnerTexts()).map((s) => s.trim()).filter((s) => s !== '--None--');
    await dialog.getByRole('combobox', { name: 'Lead Status' }).press('Escape');
  });

  await test.step('Expected: "Lead Status" offers exactly New, Working, Qualified, Unqualified and Converted', async () => {
    expect([...statusOptions].sort()).toEqual(['Converted', 'New', 'Qualified', 'Unqualified', 'Working']);
  });

  await test.step('5. Open the "Lead Source" picklist', async () => {
    await dialog.getByRole('combobox', { name: 'Lead Source' }).click();
  });

  await test.step('Expected: the "Lead Source" options include "Partner Referral"', async () => {
    const listbox = dialog.getByRole('listbox', { name: 'Lead Source' });
    await expect(listbox.getByRole('option', { name: 'Partner Referral', exact: true })).toBeVisible();
    await dialog.getByRole('combobox', { name: 'Lead Source' }).press('Escape');
  });

  await test.step('6. Click "Cancel"', async () => {
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toBeHidden();
  });
});
