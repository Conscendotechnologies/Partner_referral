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

  await test.step('5. Open the "Related" tab and open "Account History"', async () => {
    await maya.getByRole('tab', { name: 'Related', exact: true }).click();
    const historyLink = maya.getByRole('link', { name: /^Account History/ }).first();
    await expect(historyLink).toBeVisible({ timeout: 60_000 });
    await historyLink.click();
    await expect(maya.getByRole('heading', { name: 'Account History' }).first()).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: a "Commission Rate" history row shows the old value, the new value 61, "Maya Manager (PR test)" and the date and time', async () => {
    // Account History columns: Date, Field, User, Original Value, New Value. Maya's locale is en_AU.
    const row = maya
      .getByRole('grid')
      .getByRole('row')
      .filter({ has: maya.getByRole('gridcell', { name: 'Commission Rate', exact: true }) })
      .filter({ has: maya.getByRole('gridcell', { name: /\b61(\.00)?$/ }) })
      .filter({ hasText: 'Maya Manager (PR test)' })
      .first();
    await expect(row).toBeVisible({ timeout: 60_000 });
    await expect(row).toContainText(/\d{1,2}\/\d{1,2}\/\d{4},? \d{1,2}:\d{2}\s*[ap]m/i);
    // The old value (Original Value) is a rate, not empty.
    const cells = await row.getByRole('gridcell').allInnerTexts();
    expect(cells.filter((c) => /\d/.test(c) && !/\b61(\.00)?$/.test(c.trim()) && !/\//.test(c)).length).toBeGreaterThan(0);
  });
});
