// Shared steps for the group A specs (stories 00, 01, 03, 08, 10). Each asserts that its step worked.
import { expect, type Locator, type Page } from '@playwright/test';

/** A date `days` from today as the admin's (en_US) date input expects it, e.g. "12/31/2026". */
export function usDate(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return `${d.getMonth() + 1}/${d.getDate()}/${d.getFullYear()}`;
}

/**
 * Parses a Lightning date/time as displayed: en_US "11/19/2026, 3:12 AM" or en_AU "19/11/2026, 3:12 am". Returns
 * epoch ms in the machine's time zone; only compare values shown to the same user.
 */
export function parseSfDateTime(s: string, locale: 'en_US' | 'en_AU'): number {
  const m = s.match(/(\d{1,2})\/(\d{1,2})\/(\d{4}),?\s+(\d{1,2}):(\d{2})\s*([ap]m)/i);
  if (!m) throw new Error(`Not a date/time: "${s}"`);
  const [month, day] = locale === 'en_US' ? [Number(m[1]), Number(m[2])] : [Number(m[2]), Number(m[1])];
  const hour = (Number(m[4]) % 12) + (m[6].toLowerCase() === 'pm' ? 12 : 0);
  return new Date(Number(m[3]), month - 1, day, hour, Number(m[5])).getTime();
}

/** App Launcher > search the app by name > open it. Checks the app name in the header. */
export async function openApp(page: Page, appName: string) {
  await page.getByRole('button', { name: 'App Launcher' }).click();
  const search = page.getByRole('combobox', { name: 'Search apps and items...' });
  await expect(search).toBeVisible({ timeout: 60_000 });
  await search.fill(appName);
  await page.getByRole('option', { name: appName, exact: true }).click();
  await expect(page.locator('.appName, one-app-nav-bar').getByText(appName, { exact: true }).first()).toBeVisible({ timeout: 60_000 });
}

/**
 * Cleanup for the agency cases: if a save the case expected to be refused went through, put the Account's field back
 * to `original` with the same user, so a defect never leaves agency data changed. Does nothing when the value is
 * still `original`. `set` fills the field in the open edit dialog.
 */
export async function restoreAccountField(page: Page, agency: string, label: string, original: string, set: (dialog: Locator) => Promise<void>) {
  const dialog = page.getByRole('dialog', { name: `Edit ${agency}` });
  // A caller may pass the whole layout-item text it noted (label, value and the hidden "Edit <label>" text): only the
  // value line is compared.
  original = shownValue(original, label);
  // Cleanup after a failed check can find the edit form still open, and its unsaved changes block the reload. Cancel it
  // first (this only tidies up; it decides nothing about the test's result), then reload for fresh values.
  if (await dialog.isVisible()) {
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toBeHidden({ timeout: 30_000 });
  }
  await page.reload();
  const details = page.getByRole('tab', { name: 'Details' });
  await expect(details).toBeVisible({ timeout: 90_000 });
  await details.click();
  await expect(detailField(page, 'Account Name')).toContainText(agency, { timeout: 60_000 });
  // Skipped only when Details shows exactly the original value. When Details doesn't show the field, the form still
  // may have changed it, so the value is always put back.
  const field = detailField(page, label);
  if ((await field.count()) === 1 && sameValue(shownValue(await field.innerText(), label), original)) return;
  await page.getByRole('button', { name: 'Edit', exact: true }).click();
  await expect(dialog.getByRole('textbox', { name: 'Account Name' })).toHaveValue(agency, { timeout: 60_000 });
  await set(dialog);
  await dialog.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(dialog).toBeHidden({ timeout: 60_000 });
  const restored = detailField(page, label);
  if ((await restored.count()) === 1) {
    await expect.poll(async () => sameValue(shownValue(await restored.innerText(), label), original)).toBe(true);
  }
}

/**
 * Replaces an input's whole value. `fill` on a Lightning number field (spinbutton) can append to the formatted value
 * ("60" + "61" became "6061"), so the contents are selected and deleted, then typed, and the result is checked.
 */
export async function replaceValue(input: Locator, value: string) {
  await input.click();
  await input.press('ControlOrMeta+a');
  await input.press('Delete');
  await expect(input).toHaveValue('');
  await input.pressSequentially(value);
  await expect(input).toHaveValue(new RegExp(`^${value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`));
}

/** The value line of a layout item's text (which also holds the label and the hidden "Edit <label>" button text). */
function shownValue(text: string, label: string): string {
  const lines = text.split('\n').map((l) => l.trim()).filter((l) => l && l !== label && !l.startsWith('Edit ') && !l.startsWith('Help '));
  return lines[0] ?? '';
}

/**
 * Whole-value comparison for restoreAccountField: numbers by value ("61" is not "6", "50.00" is "50"; spaces in an
 * ABN ignored), anything else as trimmed text.
 */
function sameValue(shown: string, original: string): boolean {
  const a = shown.trim();
  const b = original.trim();
  const num = (s: string) => (/^[\d\s.,%]+$/.test(s) ? Number(s.replace(/[\s,%]/g, '')) : NaN);
  if (!Number.isNaN(num(a)) && !Number.isNaN(num(b))) return num(a) === num(b);
  return a === b;
}

/**
 * Dashboards tab > All Folders > `folder` > `dashboard`. Returns once the dashboard (in its sfxdash iframe) shows its
 * title.
 */
export async function openDashboardInFolder(page: Page, folder: string, dashboard: string) {
  await page.goto('/lightning/o/Dashboard/home');
  // Lightning can take more than 30 s to start right after a Login-as.
  const allFolders = page.getByRole('tab', { name: 'All Folders' });
  await expect(allFolders).toBeVisible({ timeout: 90_000 });
  await allFolders.click();
  const folderLink = page.getByRole('link', { name: folder, exact: true }).first();
  await expect(folderLink).toBeVisible({ timeout: 60_000 });
  await folderLink.click();
  await expect(page.getByRole('heading', { name: folder }).first()).toBeVisible({ timeout: 60_000 });
  const dashLink = page.getByRole('link', { name: dashboard, exact: true }).first();
  await expect(dashLink).toBeVisible({ timeout: 60_000 });
  await dashLink.click();
  const dash = page.frameLocator('iframe[name^="sfxdash"]');
  await expect(dash.getByRole('heading', { level: 1, name: dashboard })).toBeVisible({ timeout: 90_000 });
}

/**
 * Clicks the dashboard's "Refresh" and waits until it has refreshed: either the brief "Dashboard refreshed"
 * announcement, or the header's "As of <time>" moving on (the announcement can come and go between two polls).
 */
export async function refreshDashboard(page: Page) {
  const dash = page.frameLocator('iframe[name^="sfxdash"]');
  const asOf = dash.getByText(/^As of /).first();
  await expect(asOf).toBeVisible({ timeout: 60_000 });
  const before = (await asOf.innerText()).trim();
  await dash.getByRole('button', { name: 'Refresh', exact: true }).click();
  const announced = dash.getByRole('status').filter({ hasText: 'Dashboard refreshed' });
  const moved = dash.getByText(/^As of /).first().filter({ hasNotText: before });
  await expect(announced.or(moved).first()).toBeAttached({ timeout: 120_000 });
  await expect(dash.getByText('Refreshing dashboard...')).toBeHidden({ timeout: 120_000 });
}

/** The Lightning toast message. */
export function toast(page: Page): Locator {
  return page.locator('.forceToastMessage').first();
}

/** The value part of a field in a record's Details (the layout item with that exact label). */
export function detailField(page: Page, label: string): Locator {
  return page.locator(`records-record-layout-item[field-label="${label}"]`).first();
}

/** Leads tab > "New" > the Partner Referral form. Returns the open "New Lead: Partner Referral" dialog. */
export async function openNewPartnerReferralLead(page: Page): Promise<Locator> {
  await page.goto('/lightning/o/Lead/list');
  const newButton = page.getByRole('button', { name: 'New', exact: true }).first();
  await expect(newButton).toBeVisible({ timeout: 60_000 });
  await newButton.click();
  return recordTypeForm(page, 'Lead');
}

/**
 * "Select record type "Partner Referral" and click "Next"". Partner Referral is the only active record type on Lead and
 * Opportunity in this org, so Salesforce skips the chooser and opens that form directly; this checks it did.
 */
export async function recordTypeForm(page: Page, objectLabel: string): Promise<Locator> {
  const dialog = page.getByRole('dialog', { name: `New ${objectLabel}: Partner Referral` });
  await expect(dialog.getByRole('heading', { name: `New ${objectLabel}: Partner Referral`, level: 2 })).toBeVisible({ timeout: 60_000 });
  await expect(dialog.getByRole('button', { name: 'Save', exact: true })).toBeVisible({ timeout: 60_000 });
  return dialog;
}

/**
 * Fills the S03 Partner Referral Lead steps: Last Name, Company (if shown), State/Province, Move-in Date, Utilities
 * "Electricity". Company is not on the Partner Referral layout, which the step checks rather than skipping silently.
 */
export async function fillReferralLead(dialog: Locator, v: { lastName: string; state: string; moveInDays: number }) {
  await dialog.getByRole('textbox', { name: 'Last Name' }).fill(v.lastName);
  await expect(dialog.getByRole('textbox', { name: 'Last Name' })).toHaveValue(v.lastName);
  // "Enter "AI-TEST Co" in "Company" if the field is shown": the layout has no Company field.
  await expect(dialog.getByRole('textbox', { name: 'Company' })).toHaveCount(0);
  await dialog.getByRole('textbox', { name: 'State/Province' }).fill(v.state);
  await expect(dialog.getByRole('textbox', { name: 'State/Province' })).toHaveValue(v.state);
  const moveIn = usDate(v.moveInDays);
  await dialog.getByRole('textbox', { name: 'Move-in Date' }).fill(moveIn);
  await expect(dialog.getByRole('textbox', { name: 'Move-in Date' })).toHaveValue(moveIn);
  const utilities = dialog.getByRole('group', { name: 'Utilities' });
  await utilities.getByRole('listbox', { name: 'Available' }).getByRole('option', { name: 'Electricity', exact: true }).click();
  await utilities.getByRole('button', { name: 'Move selection to Chosen' }).click();
  await expect(utilities.getByRole('listbox', { name: 'Chosen' }).getByRole('option', { name: 'Electricity', exact: true })).toBeVisible();
}

/** Clicks Save on a new-record dialog and waits for the saved Lead's record page (toast + page heading). */
export async function saveNewLead(page: Page, dialog: Locator, lastName: string) {
  await dialog.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(toast(page)).toContainText(`Lead "${lastName}" was created`, { timeout: 60_000 });
  await expect(dialog).toBeHidden();
  await expect(page).toHaveURL(/\/lightning\/r\/(Lead\/)?00Q\w+\/view/);
  await expect(page.locator('records-highlights2').getByText(lastName, { exact: true })).toBeVisible({ timeout: 60_000 });
}
