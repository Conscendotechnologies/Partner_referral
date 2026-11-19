import { test, expect } from './support/fixtures';
import { fieldItem, fieldValue, openNewestLead, openReferralFromLead, showDetails } from './support/B';

// Uses the referral S02-TC-01 sent earlier in this run: its Lead is the newest open Lead named "AI-TEST Mover 0201 ...".
test('S02-TC-02: The submitted referral creates one Referral owned by the agent and one linked Partner Referral Lead with state code', async ({ page }) => {
  let leadName = '';
  let referralNumber = '';

  await test.step('Steps 1-2: Leads > "All Open Leads", open the newest "AI-TEST Mover 0201 ..." Lead (Created Date, newest first)', async () => {
    await openNewestLead(page, 'AI-TEST Mover 0201 ');
    leadName = (await page.getByRole('heading', { level: 1, name: /^AI-TEST Mover 0201 / }).textContent())!.trim();
  });

  await test.step('Step 3: Click the Referral link on the Lead', async () => {
    referralNumber = await openReferralFromLead(page);
  });

  await test.step('Expected: the Referral\'s owner is Tom Nguyen and its Lead field links to a Lead', async () => {
    await expect(fieldItem(page, 'Owner').getByRole('link')).toHaveText('Tom Nguyen');
    await expect(fieldItem(page, 'Lead').getByRole('link', { name: leadName, exact: true })).toBeVisible();
  });

  await test.step('Step 4: On the Referral, click the Lead link', async () => {
    await fieldItem(page, 'Lead').getByRole('link', { name: leadName, exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: leadName, exact: true })).toBeVisible({ timeout: 60_000 });
    await showDetails(page);
  });

  await test.step('Expected: record type "Partner Referral", Lead Status "New", Lead Source "Partner Referral"', async () => {
    await expect(fieldValue(page, 'Lead Record Type')).toHaveText('Partner Referral');
    await expect(fieldValue(page, 'Lead Status')).toHaveText('New');
    await expect(fieldValue(page, 'Lead Source')).toHaveText('Partner Referral');
  });

  await test.step('Expected: the address shows "1 AI-TEST Street", Parramatta, NSW 2150', async () => {
    await expect(fieldValue(page, 'Address')).toHaveText(/^1 AI-TEST Street\s*Parramatta, NSW 2150\s*Australia$/);
  });

  await test.step('Expected: the Lead\'s owner is the queue PR_NSW_ACT (label "PR - NSW + ACT")', async () => {
    await expect(fieldValue(page, 'Lead Owner')).toHaveText('PR - NSW + ACT');
  });

  await test.step('Expected: the Lead links back to the same Referral', async () => {
    await expect(fieldItem(page, 'Referral').getByRole('link').first()).toHaveText(referralNumber);
  });
});
