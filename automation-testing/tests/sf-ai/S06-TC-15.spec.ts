import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';

test("S06-TC-15: A principal sees this month's and last month's commission totals", async ({ page }) => {
  await test.step('1-3. Contacts tab, open "Priya Shah", Log in to Experience as User (Connectnow Partners)', async () => {
    await logInToPortalAs(page, 'Priya Shah');
  });

  await test.step('4. Expected: "Commission this month" and "Commission last month" tiles with an AUD amount and "ex GST"', async () => {
    const tiles = page.getByRole('region', { name: 'This month' });
    await expect(tiles).toBeVisible({ timeout: 60_000 });
    for (const label of ['Commission this month', 'Commission last month']) {
      const tile = tiles.locator('.pr-tile').filter({ has: page.getByText(label, { exact: true }) });
      await expect(tile, label).toHaveCount(1);
      // AUD shown with its symbol, e.g. "A$250.00", then the "ex GST" hint.
      await expect(tile, label).toHaveText(new RegExp(`^\\s*${label}\\s*A\\$[\\d,]+\\.\\d{2}\\s*ex GST\\s*$`));
    }
  });
});
