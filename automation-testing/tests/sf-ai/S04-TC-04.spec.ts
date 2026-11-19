import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { openTracker, trackerCard, trackerCards } from './support/B';

// Demo data (scripts/apex/pr-demo/4-sample-referrals.apex): Tom sent Olivia Harper, Noah Williams and Mia Chen; Priya
// Shah (same agency) sent Jack Patel and Grace Kelly; Bayside's agents sent Leo Martin, Zoe Wright (Chloe Tan) and
// Ethan Brown (Marco Rossi); S02-TC-13/17 have Chloe send "Mover 0210"/"Mover 0214". An agent's tracker has no
// "Sent by" column, so the other senders' referrals are checked by mover name.
test('S04-TC-04: An agent sees only their own referrals with the partner-safe columns', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Look at the referral tracker on the home page', () => openTracker(page, 'My referrals'));

  await test.step('Expected: every row was sent by Tom Nguyen (none from Priya Shah or another agency)', async () => {
    await expect(trackerCard(page, 'Olivia Harper')).toHaveCount(1);
    for (const other of ['Jack Patel', 'Grace Kelly', 'Leo Martin', 'Zoe Wright', 'Ethan Brown', 'Mover 0214', 'Mover 0210']) {
      await expect(trackerCard(page, other), other).toHaveCount(0);
    }
  });

  await test.step('Expected: rows show mover name, Move-in, Services, status and Connectnow rep', async () => {
    const cards = trackerCards(page);
    const n = await cards.count();
    expect(n).toBeGreaterThan(0);
    for (let i = 0; i < n; i++) {
      const card = cards.nth(i);
      await expect(card.locator('.pr-card__name')).toHaveText(/\S/);
      await expect(card.locator('.pr-badge')).toHaveText(/^(Received|In Progress|Connected|Closed Lost)$/);
      // Exactly these details, in this order: no loss reason, plan, retailer, notes or "Sent by".
      await expect(card.locator('dt')).toHaveText(['Move-in', 'Services', 'Connectnow rep']);
    }
  });

  await test.step('Expected: the Connectnow rep column shows a first name only, never a surname', async () => {
    const reps = (await trackerCards(page).locator('dt:text-is("Connectnow rep") + dd').allTextContents()).map((r) => r.trim());
    expect(reps.length).toBe(await trackerCards(page).count());
    // A first name is one word; "Not assigned yet" is shown before a rep takes the Lead.
    expect(reps.filter((r) => r !== 'Not assigned yet' && !/^[A-Z][A-Za-z'-]*$/.test(r))).toEqual([]);
  });

  await test.step('Expected: no loss reason, plan, retailer or internal notes are shown', async () => {
    const tracker = page.locator('c-pr-my-referrals');
    await expect(tracker.getByRole('heading', { name: 'My referrals' })).toBeVisible();
    await expect(tracker).not.toContainText(/loss reason|\bplan\b|retailer|notes|description/i);
  });
});
