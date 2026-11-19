import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { openTracker, trackerCard, trackerCards } from './support/B';

// Demo data (scripts/apex/pr-demo/4-sample-referrals.apex): Marco sent Ethan Brown; Harbour & Co Realty's Tom Nguyen
// and Priya Shah sent Olivia Harper, Noah Williams, Mia Chen, Jack Patel and Grace Kelly.
test("S04-TC-06: Agency B's principal sees none of agency A's referrals", async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Marco Rossi" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Marco Rossi'));
  await test.step('Step 4: Look at the referral tracker on the home page', () => openTracker(page, 'Agency referrals'));

  await test.step('Expected: no referral sent by Tom Nguyen or Priya Shah (Harbour & Co Realty) is listed', async () => {
    const sentBy = trackerCards(page).locator('dt:text-is("Sent by") + dd');
    await expect(trackerCard(page, 'Ethan Brown')).toHaveCount(1);
    await expect(sentBy).toHaveCount(await trackerCards(page).count());
    await expect(sentBy.filter({ hasText: /^(Tom Nguyen|Priya Shah)$/ })).toHaveCount(0);
    for (const other of ['Olivia Harper', 'Noah Williams', 'Mia Chen', 'Jack Patel', 'Grace Kelly']) {
      await expect(trackerCard(page, other), other).toHaveCount(0);
    }
  });
});
