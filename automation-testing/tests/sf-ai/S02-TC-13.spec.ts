import { test, expect } from './support/fixtures';
import { logInToPortalAs, openFromList } from './support/salesforce';
import { daysFromToday, fieldValue, fillReferral, openReferForm, openTracker, referralSent, showDetails, trackerCard } from './support/B';

// Precondition: Bayside Property Group's Partner Status is "Inactive". Specs never edit agency Accounts, so this spec
// only checks that the precondition holds (read-only) and stops there when it does not. Expected to fail while D3 is
// open: Partner Status is not on the Account page, so the precondition can be neither set nor seen in the UI.
test('S02-TC-13: An agent of an inactive agency cannot submit and nothing is created', async ({ page }) => {
  await test.step('Precondition: Bayside Property Group\'s Partner Status is "Inactive"', async () => {
    await openFromList(page, 'Account', 'Bayside Property Group', 'Bayside Property Group');
    await showDetails(page);
    await expect(fieldValue(page, 'Partner Status')).toHaveText('Inactive');
  });

  await test.step('Steps 1-3: Contacts > "Chloe Tan" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Chloe Tan'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await fillReferral(page, { lastName: 'Mover 0210', mobile: '0412 000 210', moveIn: daysFromToday(30) });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: the inactive-agency message is shown', async () => {
    await expect(page.getByRole('alert')).toHaveText(
      'Your agency is not active, so new referrals cannot be submitted. Contact your Connectnow Partner Manager.'
    );
  });
  await test.step('Expected: "Referral sent" is not shown', async () => {
    await expect(referralSent(page)).toHaveCount(0);
  });
  await test.step('Expected: the tracker shows no referral for "Mover 0210"', async () => {
    await openTracker(page, 'My referrals');
    await expect(trackerCard(page, 'Mover 0210').filter({ has: page.locator('.pr-badge', { hasText: /^(Received|In Progress)$/ }) })).toHaveCount(0);
  });
});
