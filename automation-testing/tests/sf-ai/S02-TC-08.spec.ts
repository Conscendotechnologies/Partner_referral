import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { daysFromToday, fieldError, fillReferral, openReferForm, referralSent } from './support/B';

test('S02-TC-08: A move-in date 8 days in the past is rejected', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await fillReferral(page, { lastName: 'Mover 0206', mobile: '0412 000 206', moveIn: daysFromToday(-8) });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: the Move-in date field shows "No more than 7 days ago."', async () => {
    await expect(fieldError(page, 'moveInDate')).toContainText('No more than 7 days ago.');
  });
  await test.step('Expected: no referral is sent', async () => {
    await expect(page.getByRole('heading', { name: 'Refer a mover', level: 2 })).toBeVisible();
    await expect(referralSent(page)).toHaveCount(0);
  });
});
