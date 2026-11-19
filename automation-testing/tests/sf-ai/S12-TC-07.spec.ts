import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { openReferForm, openTracker, tileValue, trackerCards } from './support/B';

// Checks what a partner can reach from inside the portal: the home page's components and every link on it, in both
// tabs. The admin's own session is never pointed at an internal URL.
const INTERNAL = /\/lightning\/|\/lead\/|\/opportunity\/|partner_commission|\/[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?(?:\/|$|\?)/i;

test('S12-TC-07: Partner users still see only the portal components', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));

  const links: string[] = [];
  await test.step('Step 4 / Expected: the "Refer a mover" form, the tiles and the tracker are shown', async () => {
    await expect(page).toHaveURL(/\/partners\//);
    await expect(page.getByRole('heading', { level: 1, name: 'Welcome, Harbour & Co Realty' })).toBeVisible();
    for (const s of ['Referrals this month', 'Received', 'In Progress', 'Connected', 'Closed Lost']) {
      await expect(tileValue(page, s), s).toHaveText(/^\d+$/);
    }
    await openReferForm(page);
    await expect(page.getByRole('textbox', { name: 'First name' })).toBeVisible();
    links.push(...(await page.locator('a[href]').evaluateAll((as) => as.map((a) => (a as HTMLAnchorElement).href))));
    await openTracker(page, 'My referrals');
    links.push(...(await page.locator('a[href]').evaluateAll((as) => as.map((a) => (a as HTMLAnchorElement).href))));
  });

  await test.step('Expected: no internal Lead, Opportunity or commission record page is reachable from it', async () => {
    // Tracker rows are plain cards: no link to the Referral, Lead or Opportunity behind them.
    await expect(trackerCards(page).first()).toBeVisible();
    await expect(trackerCards(page).getByRole('link')).toHaveCount(0);
    // Every link on the portal home stays on the portal and none opens a record page.
    const portal = new URL(page.url()).origin;
    expect(links.length).toBeGreaterThan(0);
    expect(links.filter((h) => !h.startsWith(`${portal}/partners`) || INTERNAL.test(new URL(h).pathname))).toEqual([]);
  });
});
