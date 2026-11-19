import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { fieldItem, payoutConsole } from './support/C';

// Read-only. Precondition: a Payout Batch exists (any month).
test('S12-TC-03: Payout Batch page shows its fields, Lines and the console for that batch only', async ({ page }) => {
  let fiona = page;
  let month = '';

  await test.step('1-2. Setup > Users, Login as Fiona Finance (PR test)', async () => {
    fiona = await loginAs(page, 'Fiona', 'Finance (PR test)');
  });

  await test.step('3. Open the "Payouts" tab', async () => {
    await fiona.goto('/lightning/n/PR_Payouts');
    await expect(fiona.getByRole('heading', { name: 'Payouts', level: 1 })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('4. Click the month link of a batch', async () => {
    const card = await payoutConsole(fiona);
    const link = card.getByRole('rowheader').getByRole('link').first();
    await expect(link).toHaveText(/^\d{4}-\d{2}$/);
    month = (await link.innerText()).trim();
    await link.click();
    await expect(fiona.getByRole('heading', { level: 1, name: `Commission payout ${month}` })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: Period Month, Status, Run Count, Total and Paid On', async () => {
    for (const label of ['Period Month', 'Status', 'Run Count', 'Total (ex GST)', 'Paid On']) {
      await expect(fieldItem(fiona, label), label).toBeVisible({ timeout: 60_000 });
    }
    await expect(fieldItem(fiona, 'Period Month')).toContainText(month);
  });

  await test.step('Expected: the payout lines related list is shown', async () => {
    // The related list of Payout Line records is labelled "Lines" on the page (the case calls it "Payout Lines").
    const lines = fiona.getByRole('article', { name: 'Lines' });
    await expect(lines.getByRole('heading', { level: 2, name: /^Lines \(\d+\)$/ })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: the "Commission payouts" console lists only this batch and has no "Run payout" button', async () => {
    const card = await payoutConsole(fiona);
    await expect(card.getByRole('rowheader')).toHaveCount(1);
    await expect(card.getByRole('rowheader')).toHaveText(month);
    await expect(card.getByRole('button', { name: 'Run payout' })).toHaveCount(0);
    await expect(card.getByRole('textbox', { name: 'Payout month' })).toHaveCount(0);
  });
});
