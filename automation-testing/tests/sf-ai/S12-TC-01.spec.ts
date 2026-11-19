import { test, expect } from './support/fixtures';
import { fieldItem, fieldValue, openNewestLead, openReferralFromLead } from './support/B';

// Uses the referral S02-TC-01 sent earlier in this run (the newest open "AI-TEST Mover 0201 ..." Lead).
test('S12-TC-01: Referral page shows the mover, address, dates, services, consent, status, rep, agent, agency, Lead and Opportunity links and Commissions', async ({ page }) => {
  let leadName = '';

  await test.step('Steps 1-2: Leads > "All Open Leads", open the newest "AI-TEST Mover 0201 ..." Lead (Created Date, newest first)', async () => {
    await openNewestLead(page, 'AI-TEST Mover 0201 ');
    leadName = (await page.getByRole('heading', { level: 1, name: /^AI-TEST Mover 0201 / }).textContent())!.trim();
  });
  await test.step('Step 3: Click the Referral link on the Lead', () => openReferralFromLead(page));

  await test.step('Expected: mover name, mobile, new address, Move-in Date, Utilities, consent time and version, Status and Rep First Name', async () => {
    await expect(fieldValue(page, 'First Name')).toHaveText('AI-TEST');
    await expect(fieldValue(page, 'Last Name')).toHaveText(leadName.replace(/^AI-TEST /, ''));
    await expect(fieldItem(page, 'Mobile').getByRole('link')).toHaveText('(041) 200-0201');
    await expect(fieldValue(page, 'New Street')).toHaveText('1 AI-TEST Street');
    await expect(fieldValue(page, 'New Suburb')).toHaveText('Parramatta');
    await expect(fieldValue(page, 'New State')).toHaveText('NSW');
    await expect(fieldValue(page, 'New Postcode')).toHaveText('2150');
    await expect(fieldValue(page, 'Move-in Date')).toHaveText(/^\d{1,2}\/\d{1,2}\/\d{4}$/);
    await expect(fieldValue(page, 'Utilities')).toHaveText('Electricity');
    await expect(fieldValue(page, 'Consent Given At')).toHaveText(/^\d{1,2}\/\d{1,2}\/\d{4}, \d{1,2}:\d{2} [AP]M$/);
    await expect(fieldValue(page, 'Consent Version')).toHaveText(/^\d+$/);
    await expect(fieldValue(page, 'Status')).toHaveText(/^(Received|In Progress|Connected|Closed Lost)$/);
    // Rep_First_Name__c is labelled "Sales Rep" on the page; it stays empty until a rep owns the Lead.
    await expect(fieldItem(page, 'Sales Rep')).toBeVisible();
  });

  await test.step('Expected: Referring Agent, Referring Agency and the Lead and Opportunity links', async () => {
    await expect(fieldItem(page, 'Referring Agent').getByRole('link', { name: 'Tom Nguyen', exact: true })).toBeVisible();
    await expect(fieldItem(page, 'Referring Agency').getByRole('link', { name: 'Harbour & Co Realty', exact: true })).toBeVisible();
    await expect(fieldItem(page, 'Lead').getByRole('link', { name: leadName, exact: true })).toBeVisible();
    // Not converted yet, so the Opportunity lookup is on the page but empty.
    await expect(fieldItem(page, 'Opportunity')).toBeVisible();
  });

  await test.step('Expected: a "Commissions" related list is on the page', async () => {
    await page.getByRole('tab', { name: 'Related' }).click();
    await expect(page.getByRole('heading', { level: 2, name: /^Leads \(\d+\)$/ })).toBeVisible();
    await expect(page.getByRole('heading', { level: 2, name: /^Commissions \(\d+\)$/ })).toBeVisible();
  });
});
