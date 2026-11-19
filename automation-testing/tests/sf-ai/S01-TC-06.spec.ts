import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';

const AGENCY = 'Bayside Property Group';

// Precondition: S01-TC-03 has run, so Bayside Property Group's Commission Rate was changed to 61 by Maya.
test('S01-TC-06: A Commission Rate change appears in Account History with old value, new value, user and time', async ({ page }) => {
  test.setTimeout(300_000);
  let maya = page;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Maya Manager (PR test)"', async () => {
    maya = await loginAs(page, 'Maya', 'Manager (PR test)');
  });

  await test.step('3-4. Open the Accounts tab, search "Bayside Property Group" and open the Account', async () => {
    await openFromList(maya, 'Account', AGENCY, AGENCY);
    await expect(maya.locator('records-highlights2').getByText(AGENCY, { exact: true })).toBeVisible();
  });

  await test.step('5. Open "Account History" from the related list links at the top of the page', async () => {
    // The org's Account record page shows related lists as quick links, not under a "Related" tab.
    const historyLink = maya.getByRole('link', { name: /^Account History/ }).first();
    await expect(historyLink).toBeVisible({ timeout: 60_000 });
    await historyLink.click();
    await expect(maya.getByRole('heading', { name: 'Account History' }).first()).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: a "Commission Rate" history row shows the old value, the new value 61, "Maya Manager (PR test)" and the date and time', async () => {
    // Account History columns: Date, Field, User, Original Value, New Value. Maya's locale is en_AU.
    // Columns are read by their headers, so a cleanup row (61 -> old rate) cannot pass for the change to 61.
    const grid = maya.getByRole('grid');
    const rows = grid
      .getByRole('row')
      .filter({ has: maya.getByRole('gridcell', { name: 'Commission Rate', exact: true }) })
      .filter({ hasText: 'Maya Manager (PR test)' });
    await expect(rows.first()).toBeVisible({ timeout: 60_000 });
    const headers = (await grid.getByRole('columnheader').allInnerTexts()).map((h) => h.trim().split('\n')[0]);
    const oldCol = headers.findIndex((h) => h.startsWith('Original Value'));
    const newCol = headers.findIndex((h) => h.startsWith('New Value'));
    expect(oldCol, `"Original Value" column in ${headers.join(' | ')}`).toBeGreaterThanOrEqual(0);
    expect(newCol, `"New Value" column in ${headers.join(' | ')}`).toBeGreaterThanOrEqual(0);
    // Commission Rate is a currency field: the history shows "AUD 61" (Original Value "AUD 60").
    const sixtyOne = /^(AUD\s?)?61(\.00)?$/;
    const cellsPerRow = await Promise.all((await rows.all()).map((r) => r.locator('th, td').allInnerTexts()));
    const change = cellsPerRow
      .map((cells) => cells.map((c) => c.trim()))
      .find((cells) => sixtyOne.test(cells[newCol] ?? '') && /\d/.test(cells[oldCol] ?? '') && !sixtyOne.test(cells[oldCol]));
    expect(change, 'a Commission Rate row with New Value 61 and the old rate as Original Value').toBeDefined();
    expect(change!.join(' ')).toMatch(/\d{1,2}\/\d{1,2}\/\d{4},? \d{1,2}:\d{2}\s*[ap]m/i);
  });
});
