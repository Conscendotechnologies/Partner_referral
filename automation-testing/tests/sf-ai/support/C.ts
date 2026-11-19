// Shared steps for the S05 / S06 / S07 / S12 specs (group C). Each one does the real UI action and asserts it worked.
import { expect, type Locator, type Page } from '@playwright/test';

/**
 * The displayed value of a field in the open record's Details (the visible record page only; Lightning keeps earlier
 * record pages in the DOM, hidden). `label` is the field label as shown, e.g. 'Rate Applied'.
 */
export function fieldValue(page: Page, label: string): Locator {
  return page.locator(`records-record-layout-item[field-label="${label}"]:visible [slot="outputField"]`);
}

/** The field's whole item (label + value) in the visible record page's Details. */
export function fieldItem(page: Page, label: string): Locator {
  return page.locator(`records-record-layout-item[field-label="${label}"]:visible`);
}

/** Clicks the "Partner Commissions (n)" related list link on the open record and returns the related list grid. */
export async function openCommissionsRelatedList(page: Page): Promise<Locator> {
  const link = page.getByRole('link', { name: /^Partner Commissions \(\d+\)$/ });
  await expect(link).toBeVisible({ timeout: 60_000 });
  await link.click();
  const grid = page.getByRole('grid', { name: 'Partner Commissions' });
  await expect(grid.getByRole('rowheader').first()).toBeVisible({ timeout: 60_000 });
  return grid;
}

/** Opens the commission in `row` (a row of the Partner Commissions grid) and waits for its record page. */
export async function openCommissionRow(page: Page, row: Locator) {
  const link = row.getByRole('rowheader').getByRole('link', { name: /^COM-\d+$/ });
  const number = (await link.innerText()).trim();
  await link.click();
  await expect(page.getByRole('heading', { level: 1, name: number })).toBeVisible({ timeout: 60_000 });
  await expect(fieldValue(page, 'Status')).toBeVisible({ timeout: 60_000 });
  return number;
}

/** Opens the record's Edit dialog (the "Edit" button) and returns it once its Save button shows. */
export async function openEditDialog(page: Page): Promise<Locator> {
  await page.getByRole('button', { name: 'Edit', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: /^Edit / });
  await expect(dialog.getByRole('button', { name: 'Save', exact: true })).toBeVisible({ timeout: 60_000 });
  return dialog;
}

const ALL_VIEWS: Record<string, string> = {
  Account: 'AllAccounts',
  Contact: 'AllContacts',
  Lead: 'AllOpenLeads',
  Opportunity: 'AllOpportunities'
};

/**
 * Same steps as openFromList in salesforce.ts (the object's "All" list view, list search, open the one matching record),
 * but it waits for the searched list to settle. openFromList clicks the first matching row at once; in this org the
 * list often re-renders after the search (a spinner covers it and the row is replaced, sometimes after first showing a
 * cached row of a record that has since been renamed), so the click timed out or could open a stale record. Here the
 * click is retried until the record page whose heading is `recordName` is open.
 */
export async function openFromListSettled(page: Page, objectApiName: string, search: string, recordName: string) {
  await page.goto(`/lightning/o/${objectApiName}/list?filterName=${encodeURIComponent(ALL_VIEWS[objectApiName] ?? 'All')}`);
  const box = page.getByRole('searchbox', { name: 'Search this list...' });
  await expect(box).toBeVisible({ timeout: 60_000 });
  await box.fill(search);
  await box.press('Enter');
  const link = page.getByRole('rowheader').getByRole('link', { name: recordName, exact: true });
  await expect(link).toHaveCount(1, { timeout: 60_000 });
  const heading = page.locator('records-highlights2:visible').getByRole('heading', { level: 1 });
  await expect(async () => {
    if (!/\/lightning\/r\//.test(page.url())) await link.click({ timeout: 5_000 });
    await expect(heading).toHaveText(recordName, { timeout: 10_000 });
  }).toPass({ timeout: 120_000 });
}

/** The Lightning toast whose message matches `text`, e.g. /^Opportunity "X" was saved\.$/. */
export function savedToast(page: Page, text: RegExp): Locator {
  return page.locator('.forceToastMessage').getByText(text);
}

/** The "We hit a snag." box that lists the errors of a record form's failed save. */
export function saveErrors(page: Page): Locator {
  return page.getByRole('dialog', { name: 'We hit a snag.' });
}

/** Picks `option` in the dialog's picklist `label`. */
export async function choosePicklist(dialog: Locator, label: string, option: string) {
  await dialog.getByRole('combobox', { name: label }).click();
  await dialog.getByRole('option', { name: option, exact: true }).click();
  await expect(dialog.getByRole('combobox', { name: label })).toHaveText(option);
}

/** Today's date as an en_AU / Australia/Sydney user sees it in Lightning, e.g. "19/11/2026". */
export function todayAU(): string {
  return new Intl.DateTimeFormat('en-AU', { timeZone: 'Australia/Sydney', day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date());
}

/** "Log out as <user>" in the Login-as banner; waits until the admin session is back (the banner is gone). */
export async function logOutAs(page: Page, fullName: string) {
  const link = page.getByRole('link', { name: `Log out as ${fullName}` });
  await link.click();
  await expect(page.getByText(`Logged in as ${fullName}`)).toHaveCount(0, { timeout: 60_000 });
  // Back in the admin's own session (Setup), not on the login page: the org sometimes ends the admin session here.
  await expect(page, 'the admin session is back after "Log out as"').toHaveURL(/\/lightning\//, { timeout: 60_000 });
  await expect(page.getByRole('heading', { name: 'Salesforce login' })).toHaveCount(0);
}

/** The "Commission payouts" console card on the Payouts tab or a Payout Batch page, once its data has loaded. */
export async function payoutConsole(page: Page): Promise<Locator> {
  const card = page.getByRole('article').filter({ has: page.getByRole('heading', { name: 'Commission payouts', level: 2 }) });
  await expect(card).toBeVisible({ timeout: 60_000 });
  // The table header renders before the data; a batch row or the empty message proves the data loaded.
  await expect(card.getByRole('rowheader').first().or(card.getByText('No payout batches yet.'))).toBeVisible({ timeout: 60_000 });
  return card;
}
