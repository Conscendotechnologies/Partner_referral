import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { openTracker, tileValue, trackerCards } from './support/B';

const STATUSES = ['Received', 'In Progress', 'Connected', 'Closed Lost'];

/** "YYYY-MM" of an instant in Sydney, the partner users' time zone (the tiles count CreatedDate = THIS_MONTH). */
const sydneyMonth = (d: Date) =>
  new Intl.DateTimeFormat('en-CA', { timeZone: 'Australia/Sydney', year: 'numeric', month: '2-digit' }).format(d).slice(0, 7);

test("S04-TC-09: Home page counts this month's visible referrals by partner status", async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));

  const tiles: Record<string, number> = {};
  await test.step('Step 4 / Expected: each status tile shows a number', async () => {
    // The greeting names the agency once the home summary (which also fills the tiles) has loaded.
    await expect(page.getByRole('heading', { level: 1, name: 'Welcome, Harbour & Co Realty' })).toBeVisible();
    for (const s of STATUSES) {
      await expect(tileValue(page, s), s).toHaveText(/^\d+$/);
      tiles[s] = Number(await tileValue(page, s).textContent());
    }
  });

  await test.step("Step 5 / Expected: each tile equals the number of this month's tracker referrals with that status", async () => {
    // The tracker cards show no sent date, so the sent date of each row comes from the data the tracker itself loads
    // (its getReferrals response); the rows are then counted on screen by referral number and status badge.
    const loaded = page.waitForResponse(
      (r) => r.url().includes('/webruntime/api/apex/execute') && (r.request().postData() ?? '').includes('"getReferrals"')
    );
    await openTracker(page, 'My referrals');
    const rows: { referralNumber: string; submittedAt: string }[] = (await (await loaded).json()).returnValue;
    const thisMonth = sydneyMonth(new Date());
    const thisMonthNumbers = new Set(rows.filter((r) => sydneyMonth(new Date(r.submittedAt)) === thisMonth).map((r) => r.referralNumber));

    await expect(trackerCards(page)).toHaveCount(rows.length);
    const counted: Record<string, number> = Object.fromEntries(STATUSES.map((s) => [s, 0]));
    const n = await trackerCards(page).count();
    for (let i = 0; i < n; i++) {
      const card = trackerCards(page).nth(i);
      const number = (await card.locator('.pr-card__meta').textContent())!.split('·')[0].trim();
      if (!thisMonthNumbers.has(number)) continue;
      counted[(await card.locator('.pr-badge').textContent())!.trim()]++;
    }
    expect(counted).toEqual(tiles);
  });
});
