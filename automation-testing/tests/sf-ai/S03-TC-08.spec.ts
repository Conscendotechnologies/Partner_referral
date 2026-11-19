import { test, expect } from './support/fixtures';
import { runSuffix } from './support/salesforce';
import { noteForLaterCase } from './support/run-state';
import { detailField, fillReferralLead, parseSfDateTime, recordTypeForm, saveNewLead } from './support/groupA';

test('S03-TC-08: A new Lead shows SLA Due At', async ({ page }) => {
  const lastName = `AI-TEST SLA ${runSuffix()}`;
  const newButton = page.getByRole('button', { name: 'New', exact: true }).first();
  const dialog = page.getByRole('dialog', { name: 'New Lead: Partner Referral' });

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

  await test.step('4-8. Last Name, Company (if shown), State/Province "NSW", Move-in Date +30 days, Utilities "Electricity"', async () => {
    await fillReferralLead(dialog, { lastName, state: 'NSW', moveInDays: 30 });
  });

  await test.step('9. Click "Save"; Expected: the Lead is saved', async () => {
    await saveNewLead(page, dialog, lastName);
    // S03-TC-09 continues with this Lead.
    noteForLaterCase('S03-TC-08-lead', lastName);
  });

  await test.step('Expected: "First Contact Due" has a date and time later than the creation time', async () => {
    await page.getByRole('tab', { name: 'Details' }).click();
    // The admin's locale is en_US: "11/19/2026, 3:12 AM".
    const stamp = /\d{1,2}\/\d{1,2}\/\d{4}, \d{1,2}:\d{2} [AP]M/;
    const due = detailField(page, 'First Contact Due');
    const created = detailField(page, 'Created By');
    await expect(due).toContainText(stamp, { timeout: 60_000 });
    await expect(created).toContainText(stamp);
    const dueAt = parseSfDateTime((await due.innerText()).match(stamp)![0], 'en_US');
    const createdAt = parseSfDateTime((await created.innerText()).match(stamp)![0], 'en_US');
    expect(dueAt).toBeGreaterThan(createdAt);
  });
});
