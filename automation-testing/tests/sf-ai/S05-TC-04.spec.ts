import { test, expect } from './support/fixtures';
import { loginAs, openFromList } from './support/salesforce';

// Precondition: S05-TC-02 has run (the converted Opportunity has Electricity and Internet). Blocked by D1 until PR #8.
test('S05-TC-04: A rep can delete a product that will not be connected before Utilities Connected', async ({ page }) => {
  let sam = page;

  await test.step('1-2. Setup > Users, Login as Sam Rep (PR test)', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3-4. Opportunities tab, search "AI-TEST Convert" and open the Opportunity', async () => {
    await openFromList(sam, 'Opportunity', 'AI-TEST Convert', /^AI-TEST Convert/);
  });

  const grid = sam.getByRole('grid').filter({ has: sam.getByRole('columnheader', { name: /Quantity/ }) });
  const rows = grid.getByRole('row').filter({ has: sam.getByRole('gridcell', { name: 'Show Actions' }) });

  await test.step('5. Open the "Products" related list', async () => {
    await sam.getByRole('link', { name: /^Products \(\d+\)$/ }).click();
    await expect(sam.getByRole('heading', { level: 1, name: 'Products' })).toBeVisible({ timeout: 60_000 });
    await expect(rows.filter({ has: sam.getByRole('rowheader', { name: 'Internet' }) })).toHaveCount(1, { timeout: 60_000 });
  });

  await test.step('6. Delete the "Internet" product and confirm', async () => {
    const internet = rows.filter({ has: sam.getByRole('rowheader', { name: 'Internet' }) });
    await internet.getByRole('button', { name: 'Show Actions' }).click();
    await sam.getByRole('menuitem', { name: 'Delete', exact: true }).click();
    const confirm = sam.getByRole('dialog').filter({ has: sam.getByRole('button', { name: 'Delete', exact: true }) });
    await expect(confirm).toBeVisible();
    await confirm.getByRole('button', { name: 'Delete', exact: true }).click();
    await expect(sam.locator('.forceToastMessage').getByText(/was deleted\.$/)).toBeVisible({ timeout: 60_000 });
  });

  await test.step('Expected: the product is deleted; only Electricity remains', async () => {
    await sam.reload();
    await expect(rows).toHaveCount(1, { timeout: 60_000 });
    await expect(rows.getByRole('rowheader', { name: 'Electricity' })).toBeVisible();
    await expect(rows.getByRole('rowheader', { name: 'Internet' })).toHaveCount(0);
  });
});
