// Shared steps for the specs in tests/sf-ai. Each one does the real UI action the cases describe and asserts that it
// worked, so a spec can never silently carry on as the admin or on the wrong record.
import { expect, type Page } from '@playwright/test';

const usersFrame = (page: Page) => page.frameLocator('iframe[name^="vfFrameId"]');

/**
 * Setup > Users, then "Login" next to the user. Returns the page that runs as that user (Login opens a new tab in
 * this org) after checking the "Logged in as <name>" banner. `firstName`/`lastName` as on the User record, e.g.
 * ('Maya', 'Manager (PR test)').
 */
export async function loginAs(page: Page, firstName: string, lastName: string): Promise<Page> {
  await page.goto('/lightning/setup/ManageUsers/home');
  const frame = usersFrame(page);
  // The list is paged at 25 rows; the letter filter (last name) keeps the user on the first page.
  await expect(frame.getByRole('link', { name: lastName[0].toUpperCase(), exact: true }).first()).toBeVisible({ timeout: 60_000 });
  await frame.getByRole('link', { name: lastName[0].toUpperCase(), exact: true }).first().click();
  const row = frame.getByRole('row').filter({ has: frame.getByRole('link', { name: `${lastName}, ${firstName}`, exact: true }) });
  await expect(row).toHaveCount(1, { timeout: 60_000 });
  const popup = page.context().waitForEvent('page', { timeout: 15_000 }).catch(() => null);
  await row.getByRole('link', { name: 'Login', exact: true }).click();
  const app = (await popup) ?? page;
  await expect(app.getByText(`Logged in as ${firstName} ${lastName}`)).toBeVisible({ timeout: 60_000 });
  return app;
}

// The default "Recently Viewed" list only finds records the user opened before, so searches use an "All" view.
const ALL_VIEWS: Record<string, string> = {
  Account: 'AllAccounts',
  Contact: 'AllContacts',
  Lead: 'AllOpenLeads',
  Opportunity: 'AllOpportunities'
};

/**
 * Opens an object's list (e.g. 'Opportunity') on its "All" view, or on `listView` (a list view API name), searches it
 * and opens the one record whose name matches.
 */
export async function openFromList(
  page: Page,
  objectApiName: string,
  search: string,
  recordName: string | RegExp,
  listView = ALL_VIEWS[objectApiName] ?? 'All'
) {
  await page.goto(`/lightning/o/${objectApiName}/list?filterName=${encodeURIComponent(listView)}`);
  const box = page.getByRole('searchbox', { name: 'Search this list...' });
  await expect(box).toBeVisible({ timeout: 60_000 });
  await box.fill(search);
  await box.press('Enter');
  const link = page.getByRole('rowheader').getByRole('link', { name: recordName, exact: typeof recordName === 'string' });
  await expect(link).toHaveCount(1, { timeout: 60_000 });
  await link.click();
  await expect(page.locator('records-highlights2, records-record-layout-event-broker').first()).toBeVisible({ timeout: 60_000 });
}

/**
 * Opens the Contact from the Contacts list and uses "Log in to Experience as User" (choosing "Connectnow Partners"
 * if asked). Returns once the partner portal home has loaded.
 */
export async function logInToPortalAs(page: Page, contactName: string) {
  await openFromList(page, 'Contact', contactName, contactName);
  await page.getByRole('button', { name: 'Show more actions' }).click();
  await page.getByRole('menuitem', { name: 'Log in to Experience as User' }).click();
  const site = page.getByRole('option', { name: 'Connectnow Partners' }).or(page.getByRole('link', { name: 'Connectnow Partners' }));
  await Promise.race([
    page.waitForURL(/\/partners\//, { timeout: 60_000 }),
    site.first().waitFor({ timeout: 60_000 }).then(() => site.first().click())
  ]);
  await page.waitForURL(/\/partners\//, { timeout: 60_000 });
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible({ timeout: 60_000 });
}

/** A suffix that keeps AI-TEST record names unique per run, e.g. "1119-0342". */
export function runSuffix(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}
