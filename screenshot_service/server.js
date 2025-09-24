const puppeteer = require('puppeteer');
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;

const app = express();
const PORT = process.env.PORT || 3001;

console.log('Starting minimal server for debugging...');

// Request logging middleware - FIRST
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Middleware
app.use(cors());

// Custom JSON parsing middleware to replace express.json()
function parseJsonBody(req, res, next) {
  // Skip if not JSON content type
  if (!req.headers['content-type'] || !req.headers['content-type'].includes('application/json')) {
    return next();
  }

  console.log('Parsing JSON body manually...');
  let rawBody = '';
  
  req.setEncoding('utf8');
  
  req.on('data', chunk => {
    rawBody += chunk;
    // Prevent extremely large payloads
    if (rawBody.length > 1024 * 1024) { // 1MB limit
      res.status(413).json({ error: 'Payload too large' });
      return;
    }
  });
  
  req.on('end', () => {
    if (rawBody.length === 0) {
      req.body = {};
      return next();
    }
    
    try {
      req.body = JSON.parse(rawBody);
      console.log('JSON parsed successfully');
      next();
    } catch (error) {
      console.error('JSON parse error:', error.message);
      res.status(400).json({ error: 'Invalid JSON: ' + error.message });
    }
  });
  
  req.on('error', (error) => {
    console.error('Request stream error:', error.message);
    res.status(400).json({ error: 'Request error: ' + error.message });
  });
}

// Apply custom JSON parsing to all routes
app.use(parseJsonBody);

// URL encoded parsing for form data
app.use(express.urlencoded({ extended: true }));

// Ensure screenshots directory exists
const SCREENSHOTS_DIR = process.env.NODE_ENV === 'production' 
  ? '/home/pptruser/app/screenshots' 
  : path.join(__dirname, '../priv/static/screenshots');

async function ensureDirectoryExists() {
  try {
    await fs.access(SCREENSHOTS_DIR);
  } catch {
    await fs.mkdir(SCREENSHOTS_DIR, { recursive: true });
    console.log(`Created screenshots directory: ${SCREENSHOTS_DIR}`);
  }
}

let browser = null;

// Initialize browser on startup
async function initBrowser() {
  try {
    // Try to find system Chrome first
    const executablePaths = [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/usr/bin/google-chrome',
      '/usr/bin/chromium-browser',
      '/snap/bin/chromium'
    ];
    
    let executablePath = null;
    for (const path of executablePaths) {
      try {
        const fs = require('fs');
        await fs.promises.access(path);
        executablePath = path;
        console.log(`Found Chrome at: ${path}`);
        break;
      } catch (e) {
        // Continue to next path
      }
    }

    const launchOptions = {
      headless: "new", // Use new headless mode
      protocolTimeout: 60000, // Increase protocol timeout to 60 seconds
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-first-run',
        '--no-zygote',
        '--disable-web-security',
        '--disable-features=VizDisplayCompositor',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding'
      ]
    };

    // Use system Chrome if found, otherwise let Puppeteer handle it
    if (executablePath) {
      launchOptions.executablePath = executablePath;
    }

    browser = await puppeteer.launch(launchOptions);
    console.log('Browser initialized successfully');
  } catch (error) {
    console.error('Failed to initialize browser:', error);
    console.log('To fix this, install Chrome or run: npx puppeteer browsers install chrome');
    
    // For development, create a mock service
    console.log('Starting in mock mode - screenshots will be simulated');
    browser = null; // Will trigger mock mode
  }
}

// Screenshot endpoint
app.post('/capture-player-popup', async (req, res) => {
  let page = null;
  
  try {
    console.log('Received capture request with body:', req.body);
    const { playerData } = req.body;
    
    if (!playerData) {
      return res.status(400).json({ 
        error: 'Missing required field: playerData' 
      });
    }

    console.log(`Capturing screenshot for player: ${playerData.player_name}`);

    // Check if browser is available (mock mode if not)
    if (!browser) {
      console.log('Browser not available, creating mock screenshot');
      return createMockScreenshot(playerData, res);
    }

    // Create new page with increased timeout
    console.log('Creating new browser page...');
    page = await Promise.race([
      browser.newPage(),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error('newPage() timeout')), 30000)
      )
    ]);
    console.log('Browser page created successfully');
    
    // Set viewport for consistent screenshots
    console.log('Setting viewport...');
    await page.setViewport({ 
      width: 1200, 
      height: 800, 
      deviceScaleFactor: 2 // High DPI for crisp images
    });

    // Load the local HTML template
    const templatePath = path.join(__dirname, 'player-popup-template.html');
    const templateUrl = `file://${templatePath}`;
    
    console.log(`Loading template: ${templateUrl}`);

    // Navigate to the local template
    await page.goto(templateUrl, { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    console.log('Template loaded successfully');

    // Populate the template with player data
    console.log('Populating template with data...');
    await page.evaluate((data) => {
      window.populateTemplate(data);
    }, playerData);

    // Wait for the popup to be visible
    await page.waitForSelector('#champion-splash-popup', { 
      visible: true,
      timeout: 5000 
    });

    // Wait for images to load with timeout and better error handling
    try {
      await Promise.race([
        page.evaluate(() => {
          return Promise.all(Array.from(document.images).filter(img => !img.complete).map(img => new Promise(resolve => {
            img.onload = resolve;
            img.onerror = () => {
              console.log('Image failed to load:', img.src);
              resolve(); // Resolve anyway to not block screenshot
            };
            // Fallback timeout for individual images
            setTimeout(() => {
              console.log('Image timeout:', img.src);
              resolve();
            }, 8000);
          })));
        }),
        new Promise(resolve => setTimeout(resolve, 12000)) // Max 12 second wait for all images
      ]);
      console.log('Images loaded successfully');
    } catch (error) {
      console.log('Image loading failed, proceeding with screenshot:', error.message);
    }

    // Wait a bit more for animations and final rendering
    await page.waitForTimeout(2000);

    // Get the popup element dimensions
    const popupElement = await page.$('#champion-splash-popup');
    if (!popupElement) {
      throw new Error('Popup element not found');
    }

    // Generate unique filename with player name, pick number, and timestamp
    const timestamp = Date.now();
    const cleanPlayerName = playerData.player_name.toLowerCase().replace(/[^a-z0-9]/g, '');
    const pickNumber = playerData.pick_number || 0;
    const filename = `pick_${pickNumber}_${cleanPlayerName}_${timestamp}.png`;
    const filepath = path.join(SCREENSHOTS_DIR, filename);

    // Take screenshot of just the popup element
    await popupElement.screenshot({
      path: filepath,
      type: 'png',
      omitBackground: false // Keep the backdrop
    });

    console.log(`Screenshot saved: ${filename}`);

    // Return success response
    res.json({
      success: true,
      filename: filename,
      url: `/screenshots/${filename}`,
      playerName: playerData.player_name,
      teamName: playerData.team_name
    });

  } catch (error) {
    console.error('Screenshot capture failed:', error);
    res.status(500).json({
      error: 'Screenshot capture failed',
      details: error.message
    });
  } finally {
    if (page) {
      await page.close();
    }
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    browser: browser ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

// Test POST endpoint
app.post('/test', (req, res) => {
  console.log('Test endpoint received:', req.body);
  res.json({ 
    status: 'received',
    body: req.body,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Shutting down screenshot service...');
  if (browser) {
    await browser.close();
  }
  process.exit(0);
});

// Mock screenshot creation (for when Chrome isn't available)
async function createMockScreenshot(playerData, res) {
  try {
    const timestamp = Date.now();
    const cleanPlayerName = playerData.player_name.toLowerCase().replace(/[^a-z0-9]/g, '');
    const pickNumber = playerData.pick_number || 0;
    const filename = `mock_pick_${pickNumber}_${cleanPlayerName}_${timestamp}.png`;
    const filepath = path.join(SCREENSHOTS_DIR, filename);
    
    // Create a simple mock image using Canvas (if available) or just return success
    // For now, we'll create a simple text file as a placeholder
    const mockContent = `Mock Screenshot for ${playerData.player_name}\nTeam: ${playerData.team_name}\nPick: ${playerData.pick_number}`;
    
    await fs.writeFile(filepath.replace('.png', '.txt'), mockContent);
    
    console.log(`Mock screenshot created: ${filename}`);
    
    res.json({
      success: true,
      filename: filename,
      url: `/screenshots/${filename}`,
      playerName: playerData.player_name,
      teamName: playerData.team_name,
      mock: true
    });
  } catch (error) {
    console.error('Mock screenshot creation failed:', error);
    res.status(500).json({
      error: 'Mock screenshot creation failed',
      details: error.message
    });
  }
}

// Start server
async function startServer() {
  await ensureDirectoryExists();
  await initBrowser();
  
  app.listen(PORT, () => {
    console.log(`Screenshot service running on port ${PORT}`);
    console.log(`Screenshots will be saved to: ${SCREENSHOTS_DIR}`);
    if (!browser) {
      console.log('Running in MOCK MODE - install Chrome for real screenshots');
    }
  });
}

startServer().catch(console.error);