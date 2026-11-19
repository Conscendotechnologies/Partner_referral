import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';

test('S06-TC-16: An agent does not see the commission tiles', async ({ page }) => {
  await test.step('1-3. Contacts tab, open "Tom Nguyen", Log in to Experience as User (Connectnow Partners)', async () => {
    await logInToPortalAs(page, 'Tom Nguyen');
  });

  await test.step('4. Expected: no "Commission this month" or "Commission last month" tile', async () => {
    const tiles = page.getByRole('region', { name: 'This month' });
    // The tiles have loaded: the referral count tile is there.
    await expect(tiles.locator('.pr-tile').filter({ hasText: 'Referrals this month' })).toBeVisible({ timeout: 60_000 });
    await expect(tiles.locator('.pr-tile').filter({ hasText: 'Received' })).toBeVisible();
    await expect(tiles.getByText('Commission this month')).toHaveCount(0);
    await expect(tiles.getByText('Commission last month')).toHaveCount(0);  });
});
