import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { fieldValue, payoutConsole, todayAU } from './support/C';
import { notedByEarlierCase } from './support/run-state';

// Precondition: S07-TC-07 has run in this run (the batch is Exported). Must not run when the reset printed
// "PR-QA S07: SKIP" (CI leaves the S07 specs out then). The batch is the month S07-TC-03 ran, not any Exported one.
test('S07-TC-09: Mark paid sets the batch and every commission in it to Paid', async ({ page }) => {
  let fiona = page;
  const month = notedByEarlierCase('S07-TC-03-month');

  await test.step('1-2. Setup > Users, Login as Fiona Finance (PR test)', async () => {
    fiona = await loginAs(page, 'Fiona', 'Finance (PR test)');
  });

  await test.step('3. Open the "Payouts" tab', async () => {
    await fiona.goto('/lightning/n/PR_Payouts');
    await expect(fiona.getByRole('heading', { name: 'Payouts', level: 1 })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('4. Click "Mark paid" on the Exported batch', async () => {
    const card = await payoutConsole(fiona);
    const exported = card
      .getByRole('row')
      .filter({ has: fiona.getByRole('rowheader', { name: month, exact: true }) })
      .filter({ has: fiona.getByRole('cell', { name: 'Exported', exact: true }) });
    await expect(exported).toHaveCount(1);
    await exported.getByRole('button', { name: 'Mark paid', exact: true }).click();
    // Expected: the message appears.
    await expect(card.getByRole('status').filter({ hasText: 'marked paid' })).toHaveText(
      'Batch marked paid. Every commission in it is now Paid.',
      { timeout: 60_000 }
    );
  });

  await test.step('5. Open the batch and one of its commissions', async () => {
    const card = await payoutConsole(fiona);
    await card.getByRole('rowheader', { name: month, exact: true }).getByRole('link', { name: month, exact: true }).click();
    await expect(fiona.getByRole('heading', { level: 1, name: `Commission payout ${month}` })).toBeVisible({ timeout: 60_000 });

    // Expected: the batch is Paid with today's paid date.
    await expect(fieldValue(fiona, 'Status')).toHaveText('Paid');
    await expect(fieldValue(fiona, 'Paid On')).toHaveText(todayAU());

    // A commission of the batch: through one of its Lines, then the line's Partner Commissions related list.
    const lines = fiona.getByRole('article', { name: 'Lines' });
    await expect(lines.getByRole('link', { name: /^Lines \(\d+\)$/ })).toBeVisible({ timeout: 60_000 });
    await lines.getByRole('article').getByRole('heading', { level: 3 }).getByRole('link').first().click();
    await expect(fieldValue(fiona, 'Payment Reference')).toBeVisible({ timeout: 60_000 });
    await fiona.getByRole('tab', { name: 'Related' }).locator('visible=true').click();
    // The line's Partner Commission related list is labelled "Commissions".
    const commissions = fiona.getByRole('article', { name: 'Commissions' }).locator('visible=true');
    const commission = commissions.getByRole('grid', { name: 'Commissions' }).getByRole('rowheader').getByRole('link', { name: /^COM-\d+$/ }).first();
    await expect(commission).toBeVisible({ timeout: 60_000 });
    const number = (await commission.innerText()).trim();
    await commission.click();
    await expect(fiona.getByRole('heading', { level: 1, name: number })).toBeVisible({ timeout: 60_000 });

    // Expected: the commission Status is Paid.
    await expect(fieldValue(fiona, 'Status')).toHaveText('Paid');
  });
});
