import { test, expect } from '@playwright/test';

test.describe('Draft Real-time Features', () => {
  test.beforeEach(async ({ page }) => {
    // Setup test data - you might want to create this via API
    // For now, assuming we have a test draft with ID 1
    await page.goto('/');
  });

  test('multiple users see real-time draft updates', async ({ context }) => {
    // Create two browser contexts to simulate different users
    const organizer = await context.newPage();
    const spectator = await context.newPage();
    
    // Both users navigate to the same draft
    await organizer.goto('/drafts/new');
    await spectator.goto('/drafts/new');
    
    // Organizer creates a draft
    await organizer.fill('[name="draft[name]"]', 'Test Draft');
    await organizer.click('button[type="submit"]');
    
    // Wait for redirect and extract draft ID from URL
    await organizer.waitForURL(/\/drafts\/\d+/);
    const draftUrl = organizer.url();
    const draftId = draftUrl.match(/\/drafts\/(\d+)/)[1];
    
    // Spectator joins the same draft room
    await spectator.goto(`/drafts/${draftId}/room`);
    
    // Test real-time player selection
    if (await organizer.locator('[data-testid="player-card"]').first().isVisible()) {
      await organizer.locator('[data-testid="player-card"]').first().click();
      
      // Verify spectator sees the update
      await expect(spectator.locator('[data-testid="draft-progress"]'))
        .toContainText('picked', { timeout: 5000 });
    }
  });

  test('draft phase updates in real-time', async ({ page }) => {
    await page.goto('/drafts/1/room');
    
    // Verify initial phase
    await expect(page.locator('[data-testid="current-phase"]'))
      .toContainText('Ready to Start');
      
    // Simulate draft progression would happen here
    // This would require either:
    // 1. Multiple browser contexts picking players
    // 2. Backend simulation of draft progression
    // 3. Test helpers that trigger phase changes
  });

  test('pick timer countdown works correctly', async ({ page }) => {
    await page.goto('/drafts/1/room');
    
    // Wait for active draft state with timer
    await expect(page.locator('[data-testid="pick-timer"]'))
      .toBeVisible({ timeout: 10000 });
      
    // Verify timer counts down
    const initialTime = await page.locator('[data-testid="pick-timer"]').textContent();
    
    await page.waitForTimeout(2000);
    
    const newTime = await page.locator('[data-testid="pick-timer"]').textContent();
    expect(parseInt(newTime)).toBeLessThan(parseInt(initialTime));
  });

  test('network disconnection and reconnection', async ({ page, context }) => {
    await page.goto('/drafts/1/room');
    
    // Verify connected state
    await expect(page.locator('[data-testid="connection-status"]'))
      .toContainText('Connected');
    
    // Simulate network disconnection
    await context.setOffline(true);
    
    // Verify disconnected state appears
    await expect(page.locator('[data-testid="connection-status"]'))
      .toContainText('Disconnected', { timeout: 5000 });
    
    // Reconnect
    await context.setOffline(false);
    
    // Verify reconnection
    await expect(page.locator('[data-testid="connection-status"]'))
      .toContainText('Connected', { timeout: 10000 });
  });
});