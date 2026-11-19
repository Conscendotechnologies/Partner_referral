import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { payoutConsole } from './support/C';
import { noteForLaterCase } from './support/run-state';

// Precondition: node scripts/qa-data.mjs <org> commissions printed "PR-QA S07: READY" (every Approved commission not yet
// in a batch is AI-TEST, and the suggested month has no batch). On "PR-QA S07: SKIP" this case must not run (CI leaves
// the S07 specs out): Run payout would batch real commissions.
test('S07-TC-03: Finance runs the payout on demand from the Payouts console', async ({ page }) => {
  let fiona = page;
  let month = '';

  await test.step('1-2. Setup > Users, Login as Fiona Finance (PR test)', async () => {
    fiona = await loginAs(page, 'Fiona', 'Finance (PR test)');
  });

  await test.step('3. Open the "Payouts" tab', async () => {
    await fiona.goto('/lightning/n/PR_Payouts');
    await expect(fiona.getByRole('heading', { name: 'Payouts', level: 1 })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('4-5. Leave "Payout month" as suggested and click "Run payout"', async () => {
    const card = await payoutConsole(fiona);
    const period = card.getByRole('textbox', { name: 'Payout month' });
    await expect(period).toHaveValue(/^\d{4}-(0[1-9]|1[0-2])$/);
    month = await period.inputValue();
    await card.getByRole('button', { name: 'Run payout', exact: true }).click();
    await expect(card.getByRole('status').filter({ hasText: 'Payout for' })).toHaveText(
      `Payout for ${month} is running. Refresh in a few seconds to see the lines.`,
      { timeout: 60_000 }
    );
  });

  await test.step('6. Refresh: the batch for that month is listed as Draft with a Total ex GST', async () => {
    // "Wait 10 seconds and refresh": refresh until the queued run has written the batch (up to 2 minutes).
    await expect(async () => {
      await fiona.reload();
      const card = await payoutConsole(fiona);
      const row = card.getByRole('row').filter({ has: fiona.getByRole('rowheader', { name: month, exact: true }) });
      await expect(row).toHaveCount(1, { timeout: 5_000 });
      await expect(row.getByRole('cell').nth(0)).toHaveText('Draft', { timeout: 5_000 });
    }).toPass({ intervals: [10_000], timeout: 120_000 });
    const row = (await payoutConsole(fiona)).getByRole('row').filter({ has: fiona.getByRole('rowheader', { name: month, exact: true }) });
    // Cells after the month: Status, Agencies, Total ex GST, Runs, Actions.
    await expect(row.getByRole('cell').nth(2)).toHaveText(/^\$[\d,]+\.\d{2}$/);
    // S07-TC-07 and S07-TC-09 continue with this month's batch.
    noteForLaterCase('S07-TC-03-month', month);
  });
});
