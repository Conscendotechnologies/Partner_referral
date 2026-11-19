import { test, expect } from './support/fixtures';
import { fieldItem, fieldValue, openNewestLead, openReferralFromLead } from './support/B';

// Needs S02-TC-01 and S02-TC-17 earlier in this run. Both mover names recur across runs, so each step opens the newest
// matching open Lead (Created Date, newest first).
test('S02-TC-18: Cross-agency match flags Possible Duplicate on both referrals (internal only)', async ({ page }) => {
  await test.step('Steps 1-2: Leads > All Open Leads, open the newest "AI-TEST Mover 0214" Lead and its Referral (Chloe Tan\'s)', async () => {
    await openNewestLead(page, 'AI-TEST Mover 0214');
    await openReferralFromLead(page);
    await expect(fieldItem(page, 'Referring Agent').getByRole('link')).toHaveText('Chloe Tan');
  });
  await test.step('Expected: Chloe\'s Referral shows "Possible Duplicate" ticked', async () => {
    await expect(fieldValue(page, 'Possible Duplicate')).toHaveText(/^True/);
  });

  await test.step('Step 3: Leads > All Open Leads, open the newest "AI-TEST Mover 0201 ..." Lead and its Referral (Tom Nguyen\'s)', async () => {
    await openNewestLead(page, 'AI-TEST Mover 0201 ');
    await openReferralFromLead(page);
    await expect(fieldItem(page, 'Referring Agent').getByRole('link')).toHaveText('Tom Nguyen');
  });
  await test.step('Expected: Tom\'s Referral shows "Possible Duplicate" ticked', async () => {
    await expect(fieldValue(page, 'Possible Duplicate')).toHaveText(/^True/);
  });
});
