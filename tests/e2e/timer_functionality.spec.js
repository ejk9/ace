import { test, expect } from '@playwright/test';

test.describe('Timer Functionality - Complete Test Suite', () => {
  // Use the existing draft from the logs (draft ID 15 with organizer token)
  const ORGANIZER_URL = 'http://localhost:4000/drafts/org_t1fQzzq5-1fvJBCN_6751HyT_CT7';
  const TEAM_URL = 'http://localhost:4000/drafts/team/b9wLq-Y1rSxiA6r-IuFl9TxJ43cMIHxYJGxnUzkLg5A';
  
  test.beforeEach(async ({ page }) => {
    // Ensure we start with a clean state
    await page.goto(ORGANIZER_URL);
    await page.waitForLoadState('networkidle');
    
    // Stop any existing timer to ensure clean state
    const stopButton = page.locator('button:has-text("Stop Timer"), button[data-testid="stop-timer"]');
    if (await stopButton.isVisible()) {
      await stopButton.click();
      await page.waitForTimeout(500);
    }
  });

  test('timer initializes correctly on mount without NaN:NaN display', async ({ page }) => {
    // Navigate to the page
    await page.goto(ORGANIZER_URL);
    await page.waitForLoadState('networkidle');
    
    // Look for timer elements
    const timerDisplay = page.locator('[data-timer-display], .timer-text');
    const timerProgress = page.locator('[data-timer-progress]');
    
    // Timer should be present and not show NaN:NaN
    if (await timerDisplay.isVisible()) {
      const timerText = await timerDisplay.textContent();
      expect(timerText).not.toContain('NaN');
      expect(timerText).not.toContain('undefined');
      expect(timerText).toMatch(/\d+:\d+|\d+|STOPPED|PAUSED/);
    }
    
    // Progress element should exist
    await expect(timerProgress).toBeAttached();
  });

  test('timer reset creates paused timer with full duration', async ({ page }) => {
    // Reset the timer
    const resetButton = page.locator('button:has-text("Reset Timer"), button[data-testid="reset-timer"]');
    await expect(resetButton).toBeVisible();
    await resetButton.click();
    
    // Wait for reset to complete
    await page.waitForTimeout(1000);
    
    // Timer should show full duration and be paused
    const timerDisplay = page.locator('[data-timer-display], .timer-text');
    await expect(timerDisplay).toBeVisible();
    
    const timerText = await timerDisplay.textContent();
    expect(timerText).not.toContain('NaN');
    expect(timerText).toMatch(/\d+:\d+/); // Should show time format
    
    // Timer should not be counting down (paused state)
    const initialText = timerText;
    await page.waitForTimeout(3000);
    const afterWaitText = await timerDisplay.textContent();
    expect(afterWaitText).toBe(initialText); // Should not have changed
  });

  test('timer resumes and shows visual countdown', async ({ page }) => {
    // Reset timer first
    const resetButton = page.locator('button:has-text("Reset Timer"), button[data-testid="reset-timer"]');
    await resetButton.click();
    await page.waitForTimeout(1000);
    
    // Resume the timer
    const resumeButton = page.locator('button:has-text("Resume Timer"), button[data-testid="resume-timer"]');
    await expect(resumeButton).toBeVisible();
    await resumeButton.click();
    
    // Wait for timer to start
    await page.waitForTimeout(1000);
    
    // Timer should be counting down
    const timerDisplay = page.locator('[data-timer-display], .timer-text');
    const initialText = await timerDisplay.textContent();
    
    // Wait and verify countdown
    await page.waitForTimeout(3000);
    const afterCountdownText = await timerDisplay.textContent();
    
    expect(initialText).not.toBe(afterCountdownText); // Should have changed
    expect(afterCountdownText).not.toContain('NaN');
    expect(afterCountdownText).toMatch(/\d+:\d+/);
    
    // Extract seconds and verify countdown
    const initialSeconds = parseInt(initialText.split(':')[1]);
    const afterSeconds = parseInt(afterCountdownText.split(':')[1]);
    expect(afterSeconds).toBeLessThan(initialSeconds);
  });

  test('visual timer wheel animates during countdown', async ({ page }) => {
    // Start timer
    const resetButton = page.locator('button:has-text("Reset Timer")');
    await resetButton.click();
    await page.waitForTimeout(1000);
    
    const resumeButton = page.locator('button:has-text("Resume Timer")');
    await resumeButton.click();
    await page.waitForTimeout(1000);
    
    // Check progress circle animation
    const progressCircle = page.locator('[data-timer-progress]');
    await expect(progressCircle).toBeVisible();
    
    // Get initial style
    const initialStyle = await progressCircle.getAttribute('style');
    
    // Wait for animation
    await page.waitForTimeout(3000);
    
    // Get updated style
    const updatedStyle = await progressCircle.getAttribute('style');
    
    // Styles should be different (animation happening)
    expect(initialStyle).not.toBe(updatedStyle);
    
    // Both should contain stroke-dashoffset (progress animation)
    expect(initialStyle).toContain('stroke-dashoffset');
    expect(updatedStyle).toContain('stroke-dashoffset');
  });

  test('timer works correctly on page refresh during countdown', async ({ page }) => {
    // Start timer
    const resetButton = page.locator('button:has-text("Reset Timer")');
    await resetButton.click();
    await page.waitForTimeout(1000);
    
    const resumeButton = page.locator('button:has-text("Resume Timer")');
    await resumeButton.click();
    await page.waitForTimeout(2000); // Let it run for 2 seconds
    
    // Get timer state before refresh
    const timerDisplay = page.locator('[data-timer-display], .timer-text');
    const beforeRefreshText = await timerDisplay.textContent();
    
    // Refresh the page
    await page.reload();
    await page.waitForLoadState('networkidle');
    
    // Timer should reinitialize and continue countdown
    await expect(timerDisplay).toBeVisible({ timeout: 5000 });
    const afterRefreshText = await timerDisplay.textContent();
    
    // Should not show NaN:NaN after refresh
    expect(afterRefreshText).not.toContain('NaN');
    expect(afterRefreshText).not.toContain('undefined');
    expect(afterRefreshText).toMatch(/\d+:\d+/);
    
    // Timer should continue counting down
    await page.waitForTimeout(2000);
    const continuedText = await timerDisplay.textContent();
    expect(continuedText).not.toBe(afterRefreshText);
  });

  test('timer works correctly for late joiners', async ({ context }) => {
    // Browser 1: Organizer starts timer
    const organizerPage = await context.newPage();
    await organizerPage.goto(ORGANIZER_URL);
    await organizerPage.waitForLoadState('networkidle');
    
    // Start timer
    const resetButton = organizerPage.locator('button:has-text("Reset Timer")');
    await resetButton.click();
    await organizerPage.waitForTimeout(1000);
    
    const resumeButton = organizerPage.locator('button:has-text("Resume Timer")');
    await resumeButton.click();
    await organizerPage.waitForTimeout(3000); // Let timer run for 3 seconds
    
    // Browser 2: Team member joins after timer started (late join)
    const teamPage = await context.newPage();
    await teamPage.goto(TEAM_URL);
    await teamPage.waitForLoadState('networkidle');
    
    // Late joiner should see active timer
    const timerDisplay = teamPage.locator('[data-timer-display], .timer-text');
    await expect(timerDisplay).toBeVisible({ timeout: 5000 });
    
    const lateJoinText = await timerDisplay.textContent();
    
    // Should not show NaN:NaN for late joiner
    expect(lateJoinText).not.toContain('NaN');
    expect(lateJoinText).not.toContain('undefined');
    expect(lateJoinText).toMatch(/\d+:\d+/);
    
    // Timer should continue counting down for late joiner
    await teamPage.waitForTimeout(2000);
    const continuedText = await timerDisplay.textContent();
    expect(continuedText).not.toBe(lateJoinText);
    
    // Extract seconds and verify countdown is working
    const initialSeconds = parseInt(lateJoinText.split(':')[1]);
    const afterSeconds = parseInt(continuedText.split(':')[1]);
    expect(afterSeconds).toBeLessThan(initialSeconds);
    
    // Clean up
    await organizerPage.close();
    await teamPage.close();
  });

  test('timer state persists correctly across multiple refreshes', async ({ page }) => {
    // Start timer
    const resetButton = page.locator('button:has-text("Reset Timer")');
    await resetButton.click();
    await page.waitForTimeout(1000);
    
    const resumeButton = page.locator('button:has-text("Resume Timer")');
    await resumeButton.click();
    await page.waitForTimeout(1000);
    
    // Multiple refresh cycles
    for (let i = 0; i < 3; i++) {
      const timerDisplay = page.locator('[data-timer-display], .timer-text');
      const beforeRefreshText = await timerDisplay.textContent();
      
      await page.reload();
      await page.waitForLoadState('networkidle');
      
      // Timer should be visible and working after each refresh
      await expect(timerDisplay).toBeVisible({ timeout: 5000 });
      const afterRefreshText = await timerDisplay.textContent();
      
      // Should never show NaN:NaN
      expect(afterRefreshText).not.toContain('NaN');
      expect(afterRefreshText).not.toContain('undefined');
      expect(afterRefreshText).toMatch(/\d+:\d+/);
      
      // Verify continued countdown
      await page.waitForTimeout(1000);
      const continuedText = await timerDisplay.textContent();
      expect(continuedText).not.toBe(afterRefreshText);
    }
  });

  test('timer controls work correctly for organizers', async ({ page }) => {
    // Test reset functionality
    const resetButton = page.locator('button:has-text("Reset Timer")');
    await expect(resetButton).toBeVisible();
    await resetButton.click();
    await page.waitForTimeout(1000);
    
    // Test resume functionality
    const resumeButton = page.locator('button:has-text("Resume Timer")');
    await expect(resumeButton).toBeVisible();
    await resumeButton.click();
    await page.waitForTimeout(1000);
    
    // Test pause functionality
    const pauseButton = page.locator('button:has-text("Pause Timer")');
    if (await pauseButton.isVisible()) {
      await pauseButton.click();
      await page.waitForTimeout(1000);
      
      // Timer should be paused
      const timerDisplay = page.locator('[data-timer-display], .timer-text');
      const pausedText = await timerDisplay.textContent();
      await page.waitForTimeout(2000);
      const stillPausedText = await timerDisplay.textContent();
      expect(stillPausedText).toBe(pausedText); // Should not change when paused
    }
    
    // Test stop functionality
    const stopButton = page.locator('button:has-text("Stop Timer")');
    if (await stopButton.isVisible()) {
      await stopButton.click();
      await page.waitForTimeout(1000);
    }
  });

  test('timer displays appropriate visual states', async ({ page }) => {
    const timerDisplay = page.locator('[data-timer-display], .timer-text');
    const progressCircle = page.locator('[data-timer-progress]');
    
    // Start with reset timer
    const resetButton = page.locator('button:has-text("Reset Timer")');
    await resetButton.click();
    await page.waitForTimeout(1000);
    
    // Resume timer
    const resumeButton = page.locator('button:has-text("Resume Timer")');
    await resumeButton.click();
    await page.waitForTimeout(1000);
    
    // Check timer attributes are being set correctly
    await expect(timerDisplay).toHaveAttribute('data-timer-status', 'running');
    
    // Progress circle should have animation styles
    const progressStyle = await progressCircle.getAttribute('style');
    expect(progressStyle).toContain('stroke-dasharray');
    expect(progressStyle).toContain('stroke-dashoffset');
    
    // Timer should have remaining seconds attribute
    const remainingSecondsAttr = await timerDisplay.getAttribute('data-remaining-seconds');
    expect(parseInt(remainingSecondsAttr)).toBeGreaterThan(0);
  });
});