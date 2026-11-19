import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { fieldValue, payoutConsole } from './support/C';

// Read-only. Precondition: a Payout Batch with lines exists.
test('S12-TC-04: Payout Line page shows agency, ABN, reference, total, count and its Commissions', async ({ page }) => {
  let fiona = page;

  await test.step('1-2. Setup > Users, Login as Fiona Finance (PR test)', async () => {
    fiona = await loginAs(page, 'Fiona', 'Finance (PR test)');
  });

  await test.step('3. Open the "Payouts" tab', async () => {
    await fiona.goto('/lightning/n/PR_Payouts');
    await expect(fiona.getByRole('heading', { name: 'Payouts', level: 1 })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('4. Click the month link of a batch (one with lines)', async () => {
    const card = await payoutConsole(fiona);
    // The first batch whose "Agencies" (its line count) is above 0: a batch can exist with no lines yet.
    const rows = card.getByRole('row').filter({ has: fiona.getByRole('rowheader') });
    await expect(rows.first()).toBeVisible();
    // Cells after the month: Status, Agencies, Total ex GST, Runs, Actions.
    const counts: number[] = [];
    for (let i = 0; i < (await rows.count()); i++) counts.push(Number((await rows.nth(i).getByRole('cell').nth(1).innerText()).trim()));
    const withLines = counts.findIndex((n) => n > 0);
    expect(withLines, `a batch with lines (Agencies per row: ${counts.join(', ')})`).toBeGreaterThanOrEqual(0);
    const link = rows.nth(withLines).getByRole('rowheader').getByRole('link');
    await expect(link).toHaveText(/^\d{4}-\d{2}$/);
    const month = (await link.innerText()).trim();
    await link.click();
    await expect(fiona.getByRole('heading', { level: 1, name: `Commission payout ${month}` })).toBeVisible({ timeout: 60_000 });
  });

  let agency = '';
  await test.step('5. Open a line from the payout lines related list', async () => {
    const lines = fiona.getByRole('article', { name: 'Lines' });
    await expect(lines.getByRole('heading', { level: 2, name: /^Lines \([1-9]\d*\)$/ })).toBeVisible({ timeout: 60_000 });
    const line = lines.getByRole('article').getByRole('heading', { level: 3 }).getByRole('link').first();
    agency = (await line.innerText()).trim();
    await line.click();
    await expect(fiona.getByRole('heading', { level: 1, name: agency })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: the line shows Agency, ABN, Payment Reference, Total ex GST and Commission Count', async () => {
    await expect(fieldValue(fiona, 'Agency').getByRole('link')).toHaveText(agency);
    await expect(fieldValue(fiona, 'ABN')).toHaveText(/^\d{11}$/);
    await expect(fieldValue(fiona, 'Payment Reference')).toHaveText(/^\d{6}-\d{11}$/);
    await expect(fieldValue(fiona, 'Total (ex GST)')).toHaveText(/^AUD [\d,]+\.\d{2}/);
    await expect(fieldValue(fiona, 'Commission Count')).toHaveText(/^[1-9]\d*$/);
  });

  await test.step('Expected: a "Partner Commissions" related list shows its commissions', async () => {
    await fiona.getByRole('tab', { name: 'Related' }).locator('visible=true').click();
    // The Partner Commission related list is labelled "Commissions" on the line (the case calls it "Partner Commissions").
    const related = fiona.getByRole('article', { name: 'Commissions' }).locator('visible=true');
    await expect(related.getByRole('heading', { level: 2, name: /^Commissions \([1-9]\d*\)$/ })).toBeVisible({ timeout: 60_000 });
    await expect(related.getByRole('grid', { name: 'Commissions' }).getByRole('rowheader').getByRole('link', { name: /^COM-\d+$/ }).first()).toBeVisible();
  });
});
