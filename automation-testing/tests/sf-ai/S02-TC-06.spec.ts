import { test, expect } from './support/fixtures';
import { logInToPortalAs, runSuffix } from './support/salesforce';
import { daysFromToday, fillReferral, openReferForm, referralSent } from './support/B';

// Expected to fail while D5 is open: the form's mobile pattern rejects "+61 412 000 204" (spaces after +61).
test('S02-TC-06: A +614 mobile with spaces is accepted', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await fillReferral(page, { lastName: `Mover 0204 ${runSuffix()}`, mobile: '+61 412 000 204', moveIn: daysFromToday(30) });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: the form shows "Referral sent"', async () => {
    await expect(referralSent(page)).toBeVisible();
  });
});
