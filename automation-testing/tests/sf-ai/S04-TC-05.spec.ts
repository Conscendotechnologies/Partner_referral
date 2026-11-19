import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { openTracker, trackerCard, trackerCards } from './support/B';

// Demo data (scripts/apex/pr-demo/4-sample-referrals.apex): Bayside's agents sent Leo Martin, Zoe Wright (Chloe Tan)
// and Ethan Brown (Marco Rossi).
test('S04-TC-05: A principal sees every referral of their agency', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Priya Shah" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Priya Shah'));
  await test.step('Step 4: Look at the referral tracker on the home page', () => openTracker(page, 'Agency referrals'));

  const sentBy = () => trackerCards(page).locator('dt:text-is("Sent by") + dd');

  await test.step('Expected: referrals sent by Tom Nguyen and by Priya Shah are both listed, with the "Sent by" column', async () => {
    await expect(sentBy()).toHaveCount(await trackerCards(page).count());
    await expect(sentBy().filter({ hasText: /^Tom Nguyen$/ }).first()).toBeVisible();
    await expect(sentBy().filter({ hasText: /^Priya Shah$/ }).first()).toBeVisible();
  });

  await test.step('Expected: no referral of Bayside Property Group (Chloe Tan or Marco Rossi) is listed', async () => {
    const senders = (await sentBy().allTextContents()).map((s) => s.trim());
    expect(senders.filter((s) => s !== 'Tom Nguyen' && s !== 'Priya Shah')).toEqual([]);
    for (const other of ['Leo Martin', 'Zoe Wright', 'Ethan Brown']) {
      await expect(trackerCard(page, other), other).toHaveCount(0);
    }
  });
});
