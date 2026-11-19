import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { payoutConsole } from './support/C';

// Precondition: S07-TC-03 has run in this run (a Draft batch with lines). Must not run when the reset printed
// "PR-QA S07: SKIP" (CI leaves the S07 specs out then).
test('S07-TC-07: Download Xero CSV downloads the file and moves the batch to Exported', async ({ page }) => {
  let fiona = page;

  await test.step('1-2. Setup > Users, Login as Fiona Finance (PR test)', async () => {
    fiona = await loginAs(page, 'Fiona', 'Finance (PR test)');
  });

  await test.step('3. Open the "Payouts" tab', async () => {
    await fiona.goto('/lightning/n/PR_Payouts');
    await expect(fiona.getByRole('heading', { name: 'Payouts', level: 1 })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('4. Click "Download Xero CSV" on the Draft batch', async () => {
    const card = await payoutConsole(fiona);
    const draft = card.getByRole('row').filter({ has: fiona.getByRole('cell', { name: 'Draft', exact: true }) });
    await expect(draft).toHaveCount(1);
    const month = (await draft.getByRole('rowheader').innerText()).trim();
    expect(month).toMatch(/^\d{4}-\d{2}$/);
    const file = `connectnow-commissions-${month}.csv`;

    const download = fiona.waitForEvent('download', { timeout: 60_000 });
    await draft.getByRole('button', { name: 'Download Xero CSV', exact: true }).click();

    // Expected: the file downloads, the message appears and the batch is Exported.
    expect((await download).suggestedFilename()).toBe(file);
    await expect(card.getByRole('status').filter({ hasText: 'downloaded' })).toHaveText(
      `${file} downloaded. Upload it to Xero, then mark the batch paid.`,
      { timeout: 60_000 }
    );
    const row = card.getByRole('row').filter({ has: fiona.getByRole('rowheader', { name: month, exact: true }) });
    await expect(row.getByRole('cell').nth(0)).toHaveText('Exported', { timeout: 60_000 });
  });
});
