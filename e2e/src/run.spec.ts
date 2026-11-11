import { test, expect, Page } from '@playwright/test';

const selectors = {
  consentControlsDiv: '.md-consent__controls',
  acceptButtonText: 'Accept',
  searchInput: 'input.md-search__input[placeholder="Search"]',
  searchResultItem: 'li.md-search-result__item',
  searchLabel: 'label.md-header__button.md-icon[for="__search"]',
};

const CURRENT_BRANCH = process.env.CURRENT_BRANCH || '';

async function acceptConsentIfPresent(page: Page) {
  try {
    const accept = page.locator(
      `${selectors.consentControlsDiv} button:has-text("${selectors.acceptButtonText}")`
    );
    await accept.click({ timeout: 3000 });
  } catch (e){
    console.log("Consent banner not found or already accepted:", e);
  }
}

async function openSearchIfVisible(page: Page) {
  const searchInput = page.locator(selectors.searchInput);
  
  // Check if search is already open
  const isSearchOpen = await searchInput.isVisible({ timeout: 1000 }).catch(() => false);
  if (isSearchOpen) {
    return;
  }

  // Try to click search label to open search
  try {
    const searchLabel = page.locator(selectors.searchLabel);
    await searchLabel.click({ timeout: 3000 });
    await expect(searchInput).toBeVisible({ timeout: 5000 });
  } catch (e){
    console.log("Search label not clickable or search already open:", e);
  }
}


test.describe('Documentation Site Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Log the base URL for debugging
    console.log(`Testing against branch: ${CURRENT_BRANCH}`);
  });

  test('Verify index file exists', async ({ page }) => {
    const response = await page.goto(`/${CURRENT_BRANCH}/index.html`);

    await page.waitForLoadState('domcontentloaded');

    // Check that we are inside the branch folder
    await expect(page.url()).toContain(`${CURRENT_BRANCH}`);

    // Ensure page is not a 404. nginx serves a missing path with the branch's
    // 404.html but keeps the 404 status code, so the status is the reliable
    // signal. The body text is not: the version selector lists every deployed
    // branch, and a branch name can contain the digits "404" (for example a
    // workflow run id), which made this test fail on unrelated pull requests.
    expect(response, 'navigation returned no response').not.toBeNull();
    expect(response!.status()).toBe(200);
    await expect(page).not.toHaveTitle(/404/);
  });

  test('Search for incorrectly rendered fenced code blocks', async ({ page }) => {
    await page.goto(`/${CURRENT_BRANCH}`);
    await page.waitForLoadState('networkidle');

    await acceptConsentIfPresent(page);
    await openSearchIfVisible(page);

    const searchInput = page.locator(selectors.searchInput);
    await expect(searchInput).toBeVisible();
    
    // Fill search input
    await searchInput.fill('```');
    
    // Wait for search results to update
    await page.waitForTimeout(1500);

    // Verify no results found (meaning no incorrectly rendered code blocks)
    const searchResultItem = page.locator(selectors.searchResultItem);
    await expect(searchResultItem).toHaveCount(0, {
      timeout: 5000,
    });
  });

  test('Search for incorrectly rendered admonitions', async ({ page }) => {
    await page.goto(`/${CURRENT_BRANCH}`);
    await page.waitForLoadState('networkidle');

    await acceptConsentIfPresent(page);
    await openSearchIfVisible(page);

    const searchInput = page.locator(selectors.searchInput);
    await expect(searchInput).toBeVisible();
    
    // Fill search input
    await searchInput.fill('!!!');
    
    // Wait for search results to update
    await page.waitForTimeout(1500);

    // Verify no results found (meaning no incorrectly rendered admonitions)
    const searchResultItem = page.locator(selectors.searchResultItem);
    await expect(searchResultItem).toHaveCount(0, {
      timeout: 5000,
    });
  });
});