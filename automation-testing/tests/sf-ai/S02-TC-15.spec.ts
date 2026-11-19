import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { daysFromToday, fillReferral, openReferForm, referralSent } from './support/B';

// Needs S02-TC-01 earlier in this run (after the referrals reset): Tom's agency then has exactly one open referral with
// mobile 0412 000 201, "AI-TEST Mover 0201 <suffix>".
test('S02-TC-15: Same-agency duplicate shows a warning and can be sent anyway', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await fillReferral(page, { lastName: 'Mover 0212', mobile: '0412 000 201', moveIn: daysFromToday(30) });
  await test.step('Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: the duplicate warning lists the earlier referral', async () => {
    const warning = page.getByRole('alert').filter({ hasText: 'Your agency already referred this mover:' });
    await expect(warning).toBeVisible();
    await expect(warning.getByRole('listitem')).toHaveText([/^REF-\d+ \(AI-TEST Mover 0201 .+\)$/]);
    await expect(warning.getByText('Send it anyway only if this is a different move.', { exact: true })).toBeVisible();
    await expect(referralSent(page)).toHaveCount(0);
  });

  await test.step('Click "Send anyway"', () => page.getByRole('button', { name: 'Send anyway' }).click());
  await test.step('Expected: the form shows "Referral sent"', async () => {
    await expect(referralSent(page)).toBeVisible();
  });
});
