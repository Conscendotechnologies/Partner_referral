import type { Locator, Page } from '@playwright/test';
import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { choosePicklist, logOutAs, openCommissionRow, openCommissionsRelatedList, openEditDialog, saveErrors, openFromListSettled } from './support/C';

// Precondition: a Pending commission exists on "AI-TEST Commission QA" (S06-TC-02 in this run; while D2 is open
// S06-TC-10 cannot approve it). The expected result is itself an either/or, which the case's steps branch on too.
test('S06-TC-11: A sales rep cannot approve a commission', async ({ page }) => {
  let sam = page;
  const pendingRow = (p: Page, grid: Locator) =>
    grid.getByRole('row').filter({ has: p.getByRole('gridcell', { name: 'Pending', exact: true }) });

  await test.step('Precondition (as the admin): the Opportunity has one Pending commission', async () => {
    await openFromListSettled(page, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
    const grid = await openCommissionsRelatedList(page);
    await expect(pendingRow(page, grid)).toHaveCount(1);
  });

  await test.step('1-2. Setup > Users, Login as Sam Rep (PR test)', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3-4. Opportunities tab, search "AI-TEST Commission" and open the Opportunity', async () => {
    await openFromListSettled(sam, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
    // The related list quick links have loaded once the Products link shows.
    await expect(sam.getByRole('link', { name: /^Products \(\d+\)$/ })).toBeVisible({ timeout: 60_000 });
  });

  const commissionsLink = sam.getByRole('link', { name: /^Partner Commissions \(\d+\)$/ });
  const saveError = saveErrors(sam).getByRole('listitem').filter({ hasText: /^Only Partner Managers can approve commissions\.$/ });

  await test.step('5-6. Open a Pending commission if it is shown; if it opened, change Status to "Approved" and save', async () => {
    if ((await commissionsLink.count()) > 0) {
      const grid = await openCommissionsRelatedList(sam);
      await openCommissionRow(sam, pendingRow(sam, grid));
      const dialog = await openEditDialog(sam);
      await choosePicklist(dialog, 'Status', 'Approved');
      await dialog.getByRole('button', { name: 'Save', exact: true }).click();
    }
  });

  await test.step('Expected: Sam cannot approve (commission not reachable, or the save fails with the message)', async () => {
    const notReachable = sam
      .getByRole('list')
      .filter({ has: sam.getByRole('link', { name: /^Products \(\d+\)$/ }) })
      .filter({ hasNot: commissionsLink });
    await expect(notReachable.or(saveError).first()).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected (as the admin): the commission is still Pending', async () => {
    // Reload (closing any open edit dialog) before using the banner's log-out link.
    await sam.reload();
    await expect(sam.getByRole('link', { name: 'Log out as Sam Rep (PR test)' })).toBeVisible({ timeout: 60_000 });
    await logOutAs(sam, 'Sam Rep (PR test)');
    await openFromListSettled(sam, 'Opportunity', 'AI-TEST Commission', 'AI-TEST Commission QA');
    const grid = await openCommissionsRelatedList(sam);
    await expect(pendingRow(sam, grid)).toHaveCount(1);
    await expect(grid.getByRole('gridcell', { name: 'Approved', exact: true })).toHaveCount(0);
  });
});
