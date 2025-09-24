import { test, expect } from '@playwright/test';

test.describe('Timer Fixes - Refresh and Late Join Issues', () => {
  // Use the existing draft from the logs (draft ID 15 with organizer token)
  const ORGANIZER_URL = 'http://localhost:4000/drafts/org_t1fQzzq5-1fvJBCN_6751HyT_CT7';
  const TEAM_URL = 'http://localhost:4000/drafts/team/b9wLq-Y1rSxiA6r-IuFl9TxJ43cMIHxYJGxnUzkLg5A';
  
  test('timer displays correctly after starting and shows proper countdown', async ({ page }) => {
    // Navigate as organizer
    await page.goto(ORGANIZER_URL);
    
    // Wait for page to load
    await page.waitForLoadState('networkidle');
    
    // Look for reset timer button and click it to start a timer
    const resetButton = page.locator('button:has-text("Reset Timer"), button[data-testid="reset-timer"]');
    if (await resetButton.isVisible()) {
      await resetButton.click();
      
      // Wait for timer to start
      await page.waitForTimeout(1000);
      
      // Check that timer displays properly (not NaN:NaN)
      const timerElement = page.locator('[data-testid="pick-timer"], [phx-hook="ClientTimer"], .timer');
      await expect(timerElement).toBeVisible();
      
      const timerText = await timerElement.textContent();
      console.log('Timer text after start:', timerText);
      
      // Verify timer doesn't show NaN:NaN
      expect(timerText).not.toContain('NaN');
      expect(timerText).not.toContain('undefined');
      
      // Verify timer shows a reasonable countdown format (e.g., "0:30" or "30")
      expect(timerText).toMatch(/\d+:\d+|\d+/);
      
      // Wait a moment and verify timer counts down
      await page.waitForTimeout(2000);
      const newTimerText = await timerElement.textContent();
      console.log('Timer text after 2 seconds:', newTimerText);
      
      // Timer should have changed (counting down)
      expect(newTimerText).not.toBe(timerText);
    } else {
      console.log('Reset timer button not found - timer may already be running');
    }
  });

  test('timer works correctly on page refresh during countdown', async ({ page }) => {
    // Navigate as organizer and start timer if needed
    await page.goto(ORGANIZER_URL);
    await page.waitForLoadState('networkidle');
    
    // Start timer if not already running
    const resetButton = page.locator('button:has-text("Reset Timer"), button[data-testid="reset-timer"]');
    if (await resetButton.isVisible()) {
      await resetButton.click();
      await page.waitForTimeout(1000);
    }
    
    // Get initial timer state
    const timerElement = page.locator('[data-testid="pick-timer"], [phx-hook="ClientTimer"], .timer');
    if (await timerElement.isVisible()) {
      const initialTimerText = await timerElement.textContent();
      console.log('Timer before refresh:', initialTimerText);
      
      // Refresh the page
      await page.reload();
      await page.waitForLoadState('networkidle');
      
      // Wait for timer to appear and get its state
      await timerElement.waitFor({ state: 'visible', timeout: 5000 });
      const refreshedTimerText = await timerElement.textContent();
      console.log('Timer after refresh:', refreshedTimerText);
      
      // Verify timer doesn't show NaN:NaN after refresh
      expect(refreshedTimerText).not.toContain('NaN');
      expect(refreshedTimerText).not.toContain('undefined');
      expect(refreshedTimerText).toMatch(/\d+:\d+|\d+/);
      
      // Verify timer continues to count down
      await page.waitForTimeout(2000);
      const continuedTimerText = await timerElement.textContent();
      console.log('Timer continuing after refresh:', continuedTimerText);
      expect(continuedTimerText).not.toBe(refreshedTimerText);
    }
  });

  test('timer works correctly when joining after timer has started (late join)', async ({ context }) => {
    // First browser: organizer starts timer
    const organizerPage = await context.newPage();
    await organizerPage.goto(ORGANIZER_URL);
    await organizerPage.waitForLoadState('networkidle');
    
    // Start timer
    const resetButton = organizerPage.locator('button:has-text("Reset Timer"), button[data-testid="reset-timer"]');
    if (await resetButton.isVisible()) {
      await resetButton.click();
      await organizerPage.waitForTimeout(2000); // Let timer run for 2 seconds
    }
    
    // Second browser: team member joins after timer started (late join)
    const teamPage = await context.newPage();
    await teamPage.goto(TEAM_URL);
    await teamPage.waitForLoadState('networkidle');
    
    // Check timer display for late joiner
    const timerElement = teamPage.locator('[data-testid="pick-timer"], [phx-hook="ClientTimer"], .timer');
    await timerElement.waitFor({ state: 'visible', timeout: 5000 });
    
    const lateJoinTimerText = await timerElement.textContent();
    console.log('Timer for late joiner:', lateJoinTimerText);
    
    // Verify timer doesn't show NaN:NaN for late joiner
    expect(lateJoinTimerText).not.toContain('NaN');
    expect(lateJoinTimerText).not.toContain('undefined');
    expect(lateJoinTimerText).toMatch(/\d+:\d+|\d+/);
    
    // Verify timer continues to count down for late joiner
    await teamPage.waitForTimeout(2000);
    const continuedLateJoinTimerText = await timerElement.textContent();
    console.log('Timer continuing for late joiner:', continuedLateJoinTimerText);
    expect(continuedLateJoinTimerText).not.toBe(lateJoinTimerText);
    
    // Close pages
    await organizerPage.close();
    await teamPage.close();
  });

  test('timer state persists correctly across multiple refreshes', async ({ page }) => {
    // Navigate and start timer
    await page.goto(ORGANIZER_URL);
    await page.waitForLoadState('networkidle');
    
    const resetButton = page.locator('button:has-text("Reset Timer"), button[data-testid="reset-timer"]');
    if (await resetButton.isVisible()) {
      await resetButton.click();
      await page.waitForTimeout(1000);
    }
    
    // Multiple refresh cycles
    for (let i = 0; i < 3; i++) {
      console.log(`Refresh cycle ${i + 1}`);
      
      const timerElement = page.locator('[data-testid="pick-timer"], [phx-hook="ClientTimer"], .timer');
      if (await timerElement.isVisible()) {
        const beforeRefreshText = await timerElement.textContent();
        console.log(`Before refresh ${i + 1}:`, beforeRefreshText);
        
        await page.reload();
        await page.waitForLoadState('networkidle');
        
        await timerElement.waitFor({ state: 'visible', timeout: 5000 });
        const afterRefreshText = await timerElement.textContent();
        console.log(`After refresh ${i + 1}:`, afterRefreshText);
        
        // Each time, verify no NaN:NaN
        expect(afterRefreshText).not.toContain('NaN');
        expect(afterRefreshText).not.toContain('undefined');
        expect(afterRefreshText).toMatch(/\d+:\d+|\d+/);
      }
      
      await page.waitForTimeout(1000);
    }
  });
});