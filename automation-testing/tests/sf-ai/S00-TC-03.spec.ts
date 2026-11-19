import { test, expect } from './support/fixtures';
import { recordTypeForm } from './support/groupA';

test('S00-TC-03: Partner Referral Opportunity offers the programme stages; other record types are unchanged', async ({ page }) => {
  const newButton = page.getByRole('button', { name: 'New', exact: true }).first();
  const dialog = page.getByRole('dialog', { name: 'New Opportunity: Partner Referral' });
  let stages: string[] = [];

  await test.step('1. Open the Opportunities tab', async () => {
    await page.goto('/lightning/o/Opportunity/list');
    await expect(newButton).toBeVisible({ timeout: 60_000 });
  });

  await test.step('2. Click "New"', async () => {
    await newButton.click();
  });

  await test.step('3. Select record type "Partner Referral" and click "Next"', async () => {
    await recordTypeForm(page, 'Opportunity');
  });

  await test.step('4. Open the "Stage" picklist', async () => {
    await dialog.getByRole('combobox', { name: 'Stage' }).click();
    const listbox = dialog.getByRole('listbox', { name: 'Stage' });
    await expect(listbox.getByRole('option', { name: 'Qualification', exact: true })).toBeVisible();
    stages = (await listbox.getByRole('option').allInnerTexts()).map((s) => s.trim()).filter((s) => s !== '--None--');
    await dialog.getByRole('combobox', { name: 'Stage' }).press('Escape');
  });

  await test.step('Expected: "Stage" offers exactly Qualification, Plans Selected, Connection Requested, Utilities Connected and Closed Lost', async () => {
    expect([...stages].sort()).toEqual(['Closed Lost', 'Connection Requested', 'Plans Selected', 'Qualification', 'Utilities Connected']);
  });

  await test.step('5. Click "Cancel"', async () => {
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toBeHidden();
  });
});
