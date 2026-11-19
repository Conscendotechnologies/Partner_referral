// Shared steps for the group B specs (S02 referral form, S04 tracker, S12 record pages). Built on support/salesforce.ts.
import { expect, test, type Locator, type Page } from '@playwright/test';

// ---------- Partner portal ("Connectnow Partners") ----------

/** The "Refer a mover" tab on the portal home; checks the form has loaded for the agent's agency. */
export async function openReferForm(page: Page) {
  await page.getByRole('tab', { name: 'Refer a mover' }).click();
  await expect(page.getByRole('heading', { name: 'Refer a mover', level: 2 })).toBeVisible();
  // The button is disabled until the form's config (agency, dates, states) has loaded.
  await expect(page.getByRole('button', { name: 'Send referral' })).toBeEnabled();
}

/** A date `days` from today (negative for the past). */
export function daysFromToday(days: number): Date {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
}

/** `months` months and `days` days after today. */
export function monthsAndDaysFromToday(months: number, days: number): Date {
  const d = new Date();
  d.setMonth(d.getMonth() + months);
  d.setDate(d.getDate() + days);
  return d;
}

/**
 * The first move-in date the portal must reject as "more than 6 months ahead": its limit is Apex
 * `Date.today().addMonths(6)` on the portal user's (Sydney) calendar, and addMonths keeps the day number, clamped to the
 * last day of the month. One day after that, whatever the tester's own time zone.
 */
export function dayAfterSixMonthLimit(): Date {
  const [y, m, d] = new Intl.DateTimeFormat('en-CA', { timeZone: 'Australia/Sydney' }).format(new Date()).split('-').map(Number);
  const lastDay = new Date(y, m - 1 + 7, 0).getDate();
  const limit = new Date(y, m - 1 + 6, Math.min(d, lastDay));
  return new Date(limit.getFullYear(), limit.getMonth(), limit.getDate() + 1);
}

/** The portal's date format (shown under the field as "Format: Dec 31, 2024"). */
export function portalDate(d: Date): string {
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export type Mover = { lastName: string; mobile: string; moveIn: Date };

/**
 * The form steps every S02 submit case shares, in the case's order: First name "AI-TEST", Last name, Mobile,
 * "1 AI-TEST Street", "Parramatta", NSW, 2150, Move-in date, Electricity, consent.
 */
export async function fillReferral(page: Page, m: Mover) {
  await test.step('Enter "AI-TEST" in "First name"', () => page.getByRole('textbox', { name: 'First name' }).fill('AI-TEST'));
  await test.step(`Enter "${m.lastName}" in "Last name"`, () => page.getByRole('textbox', { name: 'Last name' }).fill(m.lastName));
  await test.step(`Enter "${m.mobile}" in "Mobile"`, () => page.getByRole('textbox', { name: 'Mobile' }).fill(m.mobile));
  await test.step('Enter "1 AI-TEST Street" in "Street"', () => page.getByRole('textbox', { name: 'Street' }).fill('1 AI-TEST Street'));
  await test.step('Enter "Parramatta" in "Suburb"', () => page.getByRole('textbox', { name: 'Suburb' }).fill('Parramatta'));
  await test.step('Select "NSW" in "State"', async () => {
    await page.getByRole('combobox', { name: 'State' }).click();
    await page.getByRole('option', { name: 'NSW', exact: true }).click();
    await expect(page.getByRole('combobox', { name: 'State' })).toHaveText('NSW');
  });
  await test.step('Enter "2150" in "Postcode"', () => page.getByRole('textbox', { name: 'Postcode' }).fill('2150'));
  await test.step(`Enter ${portalDate(m.moveIn)} in "Move-in date"`, async () => {
    const date = page.getByRole('textbox', { name: 'Move-in date' });
    await date.fill(portalDate(m.moveIn));
    await date.press('Tab');
    await expect(date).toHaveValue(portalDate(m.moveIn));
  });
  await test.step('Tick "Electricity" under "Services to connect"', async () => {
    const services = page.getByRole('group', { name: /Choose at least one/ });
    await services.getByText('Electricity', { exact: true }).click();
    await expect(services.getByRole('checkbox', { name: 'Electricity' })).toBeChecked();
  });
  await test.step('Tick "The customer gives consent"', async () => {
    await page.locator('[data-id="consent"]').getByText('The customer gives consent', { exact: true }).click();
    await expect(page.getByRole('checkbox', { name: 'The customer gives consent' })).toBeChecked();
  });
}

/** The form's success panel ("Referral sent" heading inside the status region). */
export const referralSent = (page: Page) => page.getByRole('status').filter({ has: page.getByRole('heading', { name: 'Referral sent' }) });

/** The validation message under one form field, by the field's data-id (firstName, mobile, moveInDate, utilities...). */
export const fieldError = (page: Page, dataId: string) =>
  // Each base component marks its message differently (data-help-message, data-error-message, data-helptext...), but all
  // use .slds-form-element__help; the date field's "Format: ..." hint uses it too and is not a message, and some fields
  // keep an empty, hidden one.
  page.locator(`[data-id="${dataId}"]`).locator('.slds-form-element__help').filter({ visible: true, hasNotText: /Format: / });

/** Opens the tracker tab ("My referrals" for agents, "Agency referrals" for principals) and waits for its rows. */
export async function openTracker(page: Page, label: 'My referrals' | 'Agency referrals') {
  await page.getByRole('tab', { name: label }).click();
  await expect(page.getByRole('heading', { name: label, level: 2 })).toBeVisible();
  await expect(trackerCards(page).first()).toBeVisible();
}

export const trackerCards = (page: Page) => page.locator('c-pr-my-referrals li.pr-card');

/** The tracker card(s) whose mover name contains `text`, newest first (the tracker sorts by sent date). */
export const trackerCard = (page: Page, text: string) =>
  trackerCards(page).filter({ has: page.locator('.pr-card__name', { hasText: text }) });

/** A value in a card's details grid by its term ("Move-in", "Services", "Connectnow rep", "Sent by"). */
export const cardValue = (card: Locator, term: string) => card.locator(`dt:text-is("${term}") + dd`);

/** A "Referrals this month" status tile's number. */
export const tileValue = (page: Page, label: string) =>
  page
    .getByRole('region', { name: 'This month' })
    .locator('.pr-tile')
    .filter({ has: page.locator('.pr-tile__label', { hasText: new RegExp(`^${label}$`) }) })
    .locator('.pr-tile__value');

// ---------- Internal app (Lightning) ----------

/** A field's value in the record's Details, by its label. */
export const fieldValue = (page: Page, label: string) =>
  // The output component only: the value cell also holds the "Edit <label>" / "Change ..." button's hidden text.
  fieldItem(page, label)
    .locator(
      [
        'lightning-formatted-text',
        'lightning-formatted-address',
        'lightning-formatted-number',
        'lightning-formatted-date-time',
        'lightning-formatted-rich-text',
        'records-record-type span:not(.slds-assistive-text)',
        'force-lookup',
        'lightning-input' // a read-only checkbox: its text starts with "True" or "False"
      ].join(', ')
    )
    .first();

/** A field's layout item (label, value and links) in the record's Details. */
export const fieldItem = (page: Page, label: string) =>
  page.locator(`records-record-layout-item[field-label="${label}"]`).filter({ visible: true }).first();

/** Opens the record's Details tab when the page has one (Leads open on Activity). */
export async function showDetails(page: Page) {
  await page.getByRole('tab', { name: 'Details' }).first().click();
  await expect(page.locator('records-record-layout-item').filter({ visible: true }).first()).toBeVisible();
}

/**
 * Leads tab, "All Open Leads" view, sorted by Created Date (newest first), then opens the newest Lead whose name starts
 * with `namePrefix`. The S02 cases reuse fixed mover names across runs, so "the newest matching Lead" is the one this
 * run created.
 *
 * The cases say to use the list search box, but list search runs on the search index, which picks up a new Lead only
 * minutes later (seen: a Lead 3 minutes old was missing from the results while older ones showed), so a Lead the
 * previous spec just created is not found. Sorting the whole view by Created Date finds it at once.
 */
export async function openNewestLead(page: Page, namePrefix: string) {
  await page.goto('/lightning/o/Lead/list?filterName=AllOpenLeads');
  await expect(page.getByRole('heading', { name: /All Open Leads/ })).toBeVisible({ timeout: 60_000 });
  const rows = page.getByRole('grid').getByRole('row').filter({
    has: page.getByRole('rowheader').getByRole('link', { name: new RegExp(`^${escape(namePrefix)}`) })
  });
  await expect(page.getByRole('rowheader').first()).toBeVisible({ timeout: 60_000 });
  // Newest first. The list keeps each user's last sort, so the header is clicked until it is descending.
  const header = page.getByRole('columnheader', { name: 'Created Date' });
  await expect(async () => {
    if ((await header.getAttribute('aria-sort')) !== 'descending') await page.getByRole('button', { name: 'Sort by: Created Date' }).click();
    await expect(header).toHaveAttribute('aria-sort', 'descending', { timeout: 15_000 });
  }).toPass({ timeout: 60_000 });
  await expect(page.getByRole('status', { name: 'All Open Leads' })).toContainText('Sorted by Created Date');
  // The rows are read only once the list has finished reloading (its spinner covers the grid while it loads).
  await expect(rows.first()).toBeVisible();
  await expect(page.locator('lightning-spinner').filter({ visible: true })).toHaveCount(0, { timeout: 60_000 });
  // Created Date is the view's only date-time column (the admin's locale: "11/19/2026, 3:12 PM").
  const stamp = /(\d{1,2})\/(\d{1,2})\/(\d{4}), (\d{1,2}):(\d{2}) ([AP]M)/;
  // The cells render in shadow DOM, so each row is read from its accessibility snapshot.
  const texts: string[] = [];
  for (let i = 0; i < (await rows.count()); i++) texts.push(await rows.nth(i).ariaSnapshot());
  const created = texts.map((t) => {
    const m = t.match(stamp);
    expect(m, `Created Date in row "${t}"`).not.toBeNull();
    const [, mo, d, y, h, mi, ap] = m!;
    return new Date(+y, +mo - 1, +d, (+h % 12) + (ap === 'PM' ? 12 : 0), +mi).getTime();
  });
  const newest = Math.max(...created);
  expect(created.filter((c) => c === newest), 'one newest Lead').toHaveLength(1);
  // Find that row again by its full accessible name (without the "Select Item N" position, which changes when the grid
  // re-renders): mover names repeat across runs, the name plus Created Date does not.
  const snap = texts[created.indexOf(newest)];
  const name = snap.match(/rowheader "([^"]+)"/)![1];
  const rowName = snap.match(/^- row "(.+?)":?$/m)![1].replace(/^Select Item \d+ /, '');
  const row = page.getByRole('row', { name: new RegExp(`${escape(rowName)}$`) });
  await expect(row).toHaveCount(1);
  await row.getByRole('rowheader').getByRole('link', { name, exact: true }).click();
  await expect(page.getByRole('heading', { level: 1, name, exact: true })).toBeVisible({ timeout: 60_000 });
  await showDetails(page);
}

/** On a Lead's Details, clicks its Referral link and waits for the Referral page. Returns the referral number. */
export async function openReferralFromLead(page: Page): Promise<string> {
  const link = fieldItem(page, 'Referral').getByRole('link').first();
  await expect(link).toHaveText(/^REF-\d+$/);
  const number = (await link.textContent())!.trim();
  await link.click();
  await expect(page.getByRole('heading', { level: 1, name: number })).toBeVisible({ timeout: 60_000 });
  await showDetails(page);
  return number;
}

const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
