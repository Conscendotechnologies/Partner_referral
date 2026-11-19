import { test, expect } from './support/fixtures';
import { loginAs } from './support/salesforce';
import { detailField, parseSfDateTime, toast } from './support/groupA';
import { notedByEarlierCase } from './support/run-state';

// Precondition: S03-TC-08 created "AI-TEST SLA <suffix>" earlier in this run and noted its full name.
// The list status reads "1 item", "12 items" or "50+ items".
const LIST_STATUS = /\d+\+? items?/;

test('S03-TC-09: First move to Working stamps First Contacted At', async ({ page }) => {
  test.setTimeout(300_000);
  let sam = page;
  const leadName = notedByEarlierCase('S03-TC-08-lead');
  // Sam's locale is en_AU: "19/11/2026, 3:12 pm".
  const stamp = /\d{1,2}\/\d{1,2}\/\d{4}, \d{1,2}:\d{2}\s*[ap]m/i;

  await test.step('1-2. Open Setup > Users and click "Login" next to "Sam Rep (PR test)"', async () => {
    sam = await loginAs(page, 'Sam', 'Rep (PR test)');
  });

  await test.step('3. Open the Leads tab', async () => {
    await sam.goto('/lightning/o/Lead/list');
    await expect(sam.getByRole('button', { name: /Select a List View/ })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('4. Select the "PR - NSW + ACT queue" list view', async () => {
    await sam.getByRole('button', { name: /Select a List View/ }).click();
    await sam.getByRole('option', { name: 'PR - NSW + ACT queue', exact: true }).click();
    await expect(sam.getByRole('heading', { name: /PR - NSW \+ ACT queue/ }).first()).toBeVisible({ timeout: 60_000 });
  });

  await test.step('5. Sort the view by "Created Date", newest first, and open the S03-TC-08 Lead by its full name', async () => {
    // Not the list search box: it uses the search index, which in this org had not picked up a new Lead after 10 min.
    const status = sam.getByRole('status', { name: 'PR - NSW + ACT queue' });
    await expect(status).toContainText(LIST_STATUS, { timeout: 60_000 });
    const header = sam.getByRole('columnheader', { name: 'Created Date' });
    await expect(async () => {
      if ((await header.getAttribute('aria-sort')) !== 'descending') await sam.getByRole('button', { name: 'Sort by: Created Date' }).click();
      await expect(header).toHaveAttribute('aria-sort', 'descending', { timeout: 15_000 });
    }).toPass({ timeout: 60_000 });
    await expect(status).toContainText('Sorted by Created Date');
    const link = sam.getByRole('grid').getByRole('link', { name: leadName, exact: true });
    await expect(link).toHaveCount(1, { timeout: 60_000 });
    await link.click();
    await expect(sam.locator('records-highlights2').getByText(leadName, { exact: true })).toBeVisible({ timeout: 60_000 });
  });

  await test.step('6. Check that Lead Status is "New" and "First Contacted At" is empty', async () => {
    await sam.getByRole('tab', { name: 'Details' }).click();
    await expect(detailField(sam, 'Lead Status')).toContainText('New', { timeout: 60_000 });
    await expect(detailField(sam, 'First Contact Due')).toContainText(stamp);
    await expect(detailField(sam, 'First Contacted At')).not.toContainText(stamp);
  });

  await test.step('7. Change Lead Status to "Working" and save', async () => {
    await sam.getByRole('option', { name: 'Working' }).click();
    await sam.getByRole('button', { name: 'Mark as Current Status' }).click();
    await expect(toast(sam)).toContainText('Status changed successfully', { timeout: 60_000 });
    await expect(detailField(sam, 'Lead Status')).toContainText('Working', { timeout: 60_000 });
  });

  let contactedAt = 0;
  await test.step('Expected: "First Contacted At" now shows the current date and time', async () => {
    const contacted = detailField(sam, 'First Contacted At');
    await expect(contacted).toContainText(stamp, { timeout: 60_000 });
    contactedAt = parseSfDateTime((await contacted.innerText()).match(stamp)![0], 'en_AU');
    const nowInSamZone = new Date(new Date().toLocaleString('en-US', { timeZone: 'Australia/Sydney' })).getTime();
    expect(Math.abs(nowInSamZone - contactedAt)).toBeLessThan(5 * 60_000);
  });

  await test.step('Expected: "SLA Breached" is not ticked when that time is before "First Contact Due"', async () => {
    const dueAt = parseSfDateTime((await detailField(sam, 'First Contact Due').innerText()).match(stamp)![0], 'en_AU');
    expect(contactedAt).toBeLessThan(dueAt);
    await expect(detailField(sam, 'SLA Breached')).toContainText('False');
  });
});
