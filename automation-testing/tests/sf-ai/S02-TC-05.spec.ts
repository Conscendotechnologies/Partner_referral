import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { daysFromToday, fieldError, fillReferral, openReferForm, referralSent } from './support/B';

test('S02-TC-05: A landline number is rejected as Mobile', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await fillReferral(page, { lastName: 'Mover 0203', mobile: '02 9123 4567', moveIn: daysFromToday(30) });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: the Mobile field shows "Use 04 and 8 digits, or +614 and 8 digits."', async () => {
    await expect(fieldError(page, 'mobile')).toContainText('Use 04 and 8 digits, or +614 and 8 digits.');
  });
  await test.step('Expected: no referral is sent', async () => {
    await expect(page.getByRole('heading', { name: 'Refer a mover', level: 2 })).toBeVisible();
    await expect(referralSent(page)).toHaveCount(0);
  });
});
