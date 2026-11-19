import { test, expect } from './support/fixtures';
import { logInToPortalAs, runSuffix } from './support/salesforce';
import { daysFromToday, fillReferral, openReferForm, openTracker, referralSent, trackerCard } from './support/B';

// Creates the referral "AI-TEST Mover 0201 <suffix>" (mobile 0412 000 201) that S02-TC-02, S02-TC-15, S02-TC-17,
// S04-TC-02 and S12-TC-01 use later in the same run. Needs `node scripts/qa-data.mjs <alias> referrals` first.
test('S02-TC-01: An agent submits a complete referral and sees the confirmation', async ({ page }) => {
  const lastName = `Mover 0201 ${runSuffix()}`;

  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await fillReferral(page, { lastName, mobile: '0412 000 201', moveIn: daysFromToday(30) });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: the form shows "Referral sent"', async () => {
    await expect(referralSent(page)).toBeVisible();
  });
  await test.step('Expected: the referral is in the tracker with status "Received"', async () => {
    await openTracker(page, 'My referrals');
    const card = trackerCard(page, `AI-TEST ${lastName}`);
    await expect(card).toHaveCount(1);
    await expect(card.locator('.pr-badge')).toHaveText('Received');
  });
});
