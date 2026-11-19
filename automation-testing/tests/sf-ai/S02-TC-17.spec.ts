import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { daysFromToday, fillReferral, openReferForm, referralSent } from './support/B';

// Needs S02-TC-01 earlier in this run: Harbour & Co Realty has an open referral with mobile 0412 000 201.
test('S02-TC-17: Cross-agency match submits silently', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Chloe Tan" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Chloe Tan'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await fillReferral(page, { lastName: 'Mover 0214', mobile: '0412 000 201', moveIn: daysFromToday(30) });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: "Referral sent" with no duplicate warning', async () => {
    await expect(referralSent(page)).toBeVisible();
    await expect(page.getByText('Your agency already referred this mover:')).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Send anyway' })).toHaveCount(0);
  });
});
