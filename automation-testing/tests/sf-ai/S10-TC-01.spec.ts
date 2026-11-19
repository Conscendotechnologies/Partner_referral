import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';

test('S10-TC-01: Each agency has an active principal and agent who can reach the portal', async ({ page }) => {
  test.setTimeout(300_000);

  await test.step('1-3. Open the Contacts tab, open "Marco Rossi" and click "Log in to Experience as User" (choosing "Connectnow Partners" if asked)', async () => {
    await logInToPortalAs(page, 'Marco Rossi');
  });

  await test.step('4. Look at the page header; Expected: the "Connectnow Partners" portal home page opens for Marco Rossi', async () => {
    await expect(page).toHaveURL(/\.my\.site\.com\/partners\/(s\/)?$/);
    await expect(page).toHaveTitle('Connectnow Partners');
    // The portal header shows no user name. It is Marco's home: it greets his agency (Bayside Property Group) and shows
    // the commission tiles, which only a principal gets (Bayside's other partner, Chloe Tan, is an agent).
    await expect(page.getByRole('heading', { level: 1, name: 'Welcome, Bayside Property Group' })).toBeVisible({ timeout: 60_000 });
    await expect(page.getByRole('region', { name: 'This month' })).toContainText('Commission this month');
  });
});
