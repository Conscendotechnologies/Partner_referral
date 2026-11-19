import { test, expect } from './support/fixtures';
import { logInToPortalAs } from './support/salesforce';
import { fieldError, openReferForm, referralSent } from './support/B';

test('S02-TC-03: Submitting an empty form shows a message on every required field', async ({ page }) => {
  await test.step('Steps 1-3: Contacts > "Tom Nguyen" > Log in to Experience as User (Connectnow Partners)', () =>
    logInToPortalAs(page, 'Tom Nguyen'));
  await test.step('Step 4: Click "Refer a mover"', () => openReferForm(page));
  await test.step('Step 5: Click "Send referral"', () => page.getByRole('button', { name: 'Send referral' }).click());

  await test.step('Expected: each required field shows a required-field message', async () => {
    for (const id of ['firstName', 'lastName', 'mobile', 'street', 'suburb', 'state', 'postcode']) {
      await expect(fieldError(page, id), id).toContainText('Complete this field.');
    }
    await expect(fieldError(page, 'moveInDate')).toContainText('Complete this field');
  });

  await test.step('Expected: Services to connect shows "Choose at least one"', async () => {
    const services = page.getByRole('group', { name: /Choose at least one/ });
    await expect(services).toBeVisible();
    // The group's label is "Choose at least one"; its required message appears under it.
    await expect(fieldError(page, 'utilities')).toContainText('You must select at least one choice from this set.');
  });

  await test.step('Expected: the consent checkbox shows a required message', async () => {
    await expect(page.getByRole('checkbox', { name: 'The customer gives consent' })).toHaveAttribute('aria-invalid', 'true');
    await expect(fieldError(page, 'consent')).toContainText('Complete this field.');
  });

  await test.step('Expected: Email (optional), Previous address and Notes for Connectnow show no message', async () => {
    await expect(page.getByRole('textbox', { name: 'Email (optional)' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Email (optional)' })).not.toHaveAttribute('aria-invalid', 'true');
    await expect(fieldError(page, 'email')).toHaveCount(0);
    // Previous address and Notes sit under "More details (optional)"; open it to look at them.
    await page.getByText('More details (optional)', { exact: true }).click();
    await expect(page.getByRole('textbox', { name: 'Previous address' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Notes for Connectnow' })).toBeVisible();
    await expect(fieldError(page, 'previousAddress')).toHaveCount(0);
    await expect(fieldError(page, 'notes')).toHaveCount(0);
  });

  await test.step('Expected: no referral is sent ("Referral sent" is not shown)', async () => {
    await expect(page.getByRole('heading', { name: 'Refer a mover', level: 2 })).toBeVisible();
    await expect(referralSent(page)).toHaveCount(0);
  });
});
