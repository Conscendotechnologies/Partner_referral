import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { dayAfterSixMonthLimit, fieldError, fillReferral, openReferForm, referralSent } from './support/B';

test('S02-TC-09: A move-in date more than 6 months ahead is rejected', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  // The day after the portal's limit (today in Sydney plus 6 months, as Apex addMonths counts them).
  await fillReferral(page, { lastName: 'Mover 0207', mobile: '0412 000 207', moveIn: dayAfterSixMonthLimit() });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: the Move-in date field shows "No more than 6 months ahead."', async () => {
    await expect(fieldError(page, 'moveInDate')).toContainText('No more than 6 months ahead.');
  });
  await test.step('Expected: no referral is sent', async () => {
    await expect(page.getByRole('heading', { name: 'Refer a mover', level: 2 })).toBeVisible();
    await expect(referralSent(page)).toHaveCount(0);
  });
});
