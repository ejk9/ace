# OBS Overlay Examples for Ace Draft System

This directory contains example HTML files for OBS Studio browser sources that display real-time draft information during tournament streams.

## Available Overlays

### 1. Draft Overlay (`draft_overlay.html`)
A comprehensive overlay showing:
- Draft title and status
- All teams with logos and pick progress
- Recent picks with player names and roles
- Pick timer (when active)
- Real-time updates every second for smooth timer animation

**Recommended OBS Setup:**
- Width: 1920px, Height: 1080px (full screen overlay)
- Transparency: Enabled
- Hardware acceleration: Enabled

### 2. Current Pick (`current_pick.html`)
A focused overlay showing the current team's turn:
- Large team logo and name
- Pick number and round information
- Countdown timer with color-coded warnings
- Animated pulse effect during active picks
- Compact design for corner placement

**Recommended OBS Setup:**
- Width: 400px, Height: 200px
- Position: Top-right or bottom-right corner
- Transparency: Enabled

## Setup Instructions

### Step 1: Get Your Draft ID
1. Create or access your draft in the Ace system
2. Find your draft ID from the URL (e.g., `/drafts/15/room` means draft ID is `15`)
3. The draft ID is a simple number like: `15`

### Step 2: Add to OBS Studio
1. Open OBS Studio
2. Add a new source → Browser
3. For "URL", enter the full file path to your HTML file **with the draft_id query parameter**:
   - Windows: `file:///C:/path/to/your/draft_overlay.html?draft_id=15`
   - Mac: `file:///Users/yourname/path/to/draft_overlay.html?draft_id=15`
   - Linux: `file:///home/yourname/path/to/draft_overlay.html?draft_id=15`
   - Replace `15` with your actual draft ID
4. Set the width and height as recommended above
5. Check "Shutdown source when not visible" and "Refresh browser when scene becomes active"
6. Click OK

### Step 3: Test Your Overlay
1. The overlay should load and show "Loading draft data..."
2. If configured correctly, it will switch to showing your draft information
3. If you see "Please add ?draft_id=YOUR_DRAFT_ID to the URL", make sure you included the query parameter in step 2
4. If you see "Failed to load draft data", verify your draft ID and internet connection

## API Endpoints Used

The overlays fetch data from these endpoints:
- `/stream/{id}/overlay.json` - Complete draft state
- `/stream/{id}/current.json` - Current pick information
- `/stream/{id}/teams.json` - Team comparison data
- `/stream/{id}/timeline.json` - Pick timeline

All endpoints return JSON data optimized for streaming overlays with:
- CORS headers for browser compatibility
- Cache prevention headers for real-time updates
- Timestamp fields for synchronization

## Customization

### Colors and Styling
Teams are automatically color-coded:
- Position 1: Blue (#3b82f6)
- Position 2: Red (#ef4444)
- Position 3: Green (#10b981)
- Position 4: Purple (#8b5cf6)
- Position 5: Orange (#f97316)
- Position 6: Pink (#ec4899)

### Refresh Rates
- Draft Overlay: Updates every 2 seconds
- Current Pick: Updates every 1 second
- Modify `REFRESH_INTERVAL` in the JavaScript to change

### Layout Modifications
The CSS in each file can be customized to match your stream's branding:
- Change fonts, colors, and spacing
- Modify positioning and sizes
- Add your own logos or graphics
- Adjust transparency and effects

## Troubleshooting

**"Please add ?draft_id=YOUR_DRAFT_ID to the URL"**
- You need to add the draft_id query parameter to your OBS browser source URL

**"Failed to load draft data"**
- Check that your draft ID is correct
- Verify the Ace system is running and accessible
- Check your internet connection
- Try refreshing the browser source

**Overlay appears blank**
- Check OBS browser source settings
- Verify file path is correct
- Try opening the HTML file in a regular browser first
- Check OBS logs for JavaScript errors

**Timer not updating**
- Ensure your draft has a timer configured
- Check that the draft status is "active"
- Verify the refresh interval is working

## Advanced Usage

### Custom Endpoints
You can modify the JavaScript to call different endpoints:
```javascript
// For team comparison view
const response = await fetch(`${API_BASE}/stream/${DRAFT_ID}/teams.json`);

// For pick timeline
const response = await fetch(`${API_BASE}/stream/${DRAFT_ID}/timeline.json`);
```

### Multiple Overlays
You can run multiple browser sources with different HTML files to create layered overlays:
- Main draft overlay (full screen, low opacity)
- Current pick display (corner, high opacity)
- Timer only (small, top center)

### Integration with Stream Deck
Use Stream Deck's browser source control to:
- Toggle overlays on/off during different phases
- Switch between overlay styles
- Refresh overlays after technical issues

## Support

If you encounter issues:
1. Check the browser console for JavaScript errors
2. Verify your draft ID is still valid
3. Test the API endpoints directly in a browser
4. Check that the Ace system is running and accessible

For additional features or custom overlays, contact the Ace development team.