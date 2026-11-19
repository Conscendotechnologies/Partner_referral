import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { fieldValue, openNewestLead, openTracker, trackerCard } from './support/B';

// Precondition (the case's second option): the admin moves the Lead of the referral S02-TC-01 sent earlier in this run
// (the newest open "AI-TEST Mover 0201 ..." Lead) to Working.
test('S04-TC-02: A Lead moved to Working shows "In Progress" to the agent', async ({ page }) => {
  let moverName = '';

  await test.step('Precondition: move the Lead of the S02-TC-01 referral to Working as admin', async () => {
    await openNewestLead(page, 'AI-TEST Mover 0201 ');
    moverName = (await page.getByRole('heading', { level: 1, name: /^AI-TEST Mover 0201 / }).textContent())!.trim();
    await page.getByRole('listbox', { name: 'Path Options' }).getByRole('option', { name: /Working/ }).click();
    await page.getByRole('button', { name: 'Mark as Current Status' }).click();
    await expect(fieldValue(page, 'Lead Status')).toHaveText('Working');
  });

  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));

  await test.step('Step 4 / Expected: the referral in the tracker shows "In Progress"', async () => {
    await openTracker(page, 'My referrals');
    const card = trackerCard(page, moverName);
    await expect(card).toHaveCount(1);
    await expect(card.locator('.pr-badge')).toHaveText('In Progress');
  });
});
