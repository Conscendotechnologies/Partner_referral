import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';

// Precondition: S05-TC-01 has run (Sam converted "AI-TEST Convert QA"). Blocked by D1 until PR #8.
test("S05-TC-02: The converted Opportunity has exactly the Lead's utilities as products", async ({ page }) => {
  let sam = page;

  await test.step('1-2. Setup > Users, Login as Sam Rep (PR test)', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3-4. Opportunities tab, search "AI-TEST Convert" and open the Opportunity', async () => {
    await openFromList(sam, 'Opportunity', 'AI-TEST Convert', /^AI-TEST Convert/);
  });

  await test.step('5. Open the "Products" related list', async () => {
    await sam.getByRole('link', { name: /^Products \(\d+\)$/ }).click();
    await expect(sam.getByRole('heading', { level: 1, name: 'Products' })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: exactly Electricity and Internet, each Quantity 1', async () => {
    const grid = sam.getByRole('grid').filter({ has: sam.getByRole('columnheader', { name: /Quantity/ }) });
    const rows = grid.getByRole('row').filter({ has: sam.getByRole('gridcell', { name: 'Show Actions' }) });
    await expect(rows).toHaveCount(2, { timeout: 60_000 });
    for (const product of ['Electricity', 'Internet']) {
      const row = rows.filter({ has: sam.getByRole('rowheader', { name: product }) });
      await expect(row, product).toHaveCount(1);
      await expect(row.getByRole('gridcell', { name: '1.00', exact: true }), product).toHaveCount(1);
    }
  });
});
