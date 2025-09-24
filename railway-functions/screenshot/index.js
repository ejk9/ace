// Railway Function for AceApp Screenshot Service
// This replaces the Express server for Railway's serverless functions

const puppeteer = require('puppeteer');

let browserPromise = null;

// Initialize browser with lazy loading
function getBrowser() {
  if (!browserPromise) {
    browserPromise = puppeteer.launch({
      headless: "new",
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
    });
  }
  return browserPromise;
}

// Main Railway Function handler
export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Health check
  if (req.method === 'GET' && req.url === '/health') {
    return res.status(200).json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'railway-function'
    });
  }

  // Screenshot capture endpoint
  if (req.method === 'POST' && (req.url === '/' || req.url === '/capture-player-popup')) {
    let page = null;
    
    try {
      const { playerData } = req.body;
      
      if (!playerData) {
        return res.status(400).json({ 
          error: 'Missing required field: playerData' 
        });
      }

      console.log(`Capturing screenshot for player: ${playerData.player_name}`);

      const browser = await getBrowser();
      page = await browser.newPage();
      
      // Set viewport for consistent screenshots
      await page.setViewport({ 
        width: 1200, 
        height: 800, 
        deviceScaleFactor: 2
      });

      // Create HTML content dynamically instead of loading file
      const htmlContent = generatePlayerPopupHTML(playerData);
      
      await page.setContent(htmlContent, { 
        waitUntil: 'domcontentloaded',
        timeout: 30000 
      });

      // Wait for popup to be visible
      await page.waitForSelector('#champion-splash-popup', { 
        visible: true,
        timeout: 5000 
      });

      // Wait for images to load
      await Promise.race([
        page.evaluate(() => {
          return Promise.all(Array.from(document.images).filter(img => !img.complete).map(img => new Promise(resolve => {
            img.onload = resolve;
            img.onerror = () => resolve();
            setTimeout(() => resolve(), 8000);
          })));
        }),
        new Promise(resolve => setTimeout(resolve, 12000))
      ]);

      await page.waitForTimeout(2000);

      // Take screenshot and return as base64
      const popupElement = await page.$('#champion-splash-popup');
      if (!popupElement) {
        throw new Error('Popup element not found');
      }

      const screenshot = await popupElement.screenshot({
        type: 'png',
        omitBackground: false,
        encoding: 'base64'
      });

      // Generate filename
      const timestamp = Date.now();
      const cleanPlayerName = playerData.player_name.toLowerCase().replace(/[^a-z0-9]/g, '');
      const pickNumber = playerData.pick_number || 0;
      const filename = `pick_${pickNumber}_${cleanPlayerName}_${timestamp}.png`;

      return res.status(200).json({
        success: true,
        filename: filename,
        screenshot: screenshot, // Base64 encoded PNG
        playerName: playerData.player_name,
        teamName: playerData.team_name,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Screenshot capture failed:', error);
      return res.status(500).json({
        error: 'Screenshot capture failed',
        details: error.message
      });
    } finally {
      if (page) {
        await page.close();
      }
    }
  }

  // Default 404 response
  return res.status(404).json({ error: 'Endpoint not found' });
}

// Generate the HTML content for the player popup
function generatePlayerPopupHTML(playerData) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Player Popup Screenshot</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Inter', sans-serif;
            background: transparent;
        }
        
        #champion-splash-popup {
            position: relative;
            width: 1000px;
            height: 600px;
            background: linear-gradient(135deg, #0f1419 0%, #1e2328 50%, #3c3c41 100%);
            border: 3px solid #c8aa6e;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 0 50px rgba(200, 170, 110, 0.3);
        }
        
        .backdrop {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(
                45deg,
                rgba(15, 20, 25, 0.95),
                rgba(30, 35, 40, 0.90),
                rgba(60, 60, 65, 0.85)
            );
            backdrop-filter: blur(2px);
        }
        
        .champion-splash {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-image: url('${playerData.champion_splash_url || ''}');
            background-size: cover;
            background-position: center;
            opacity: 0.6;
            z-index: 1;
        }
        
        .content {
            position: relative;
            z-index: 2;
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
            padding: 40px;
            color: white;
        }
        
        .pick-number {
            font-size: 24px;
            font-weight: 600;
            color: #c8aa6e;
            margin-bottom: 15px;
            text-transform: uppercase;
            letter-spacing: 2px;
        }
        
        .player-name {
            font-size: 48px;
            font-weight: 700;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.8);
            color: #ffffff;
        }
        
        .team-name {
            font-size: 32px;
            font-weight: 600;
            margin-bottom: 25px;
            color: ${playerData.team_color || '#c8aa6e'};
            text-shadow: 1px 1px 3px rgba(0, 0, 0, 0.7);
        }
        
        .champion-name {
            font-size: 36px;
            font-weight: 700;
            color: #f0e6d2;
            margin-bottom: 15px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.8);
        }
        
        .role-indicator {
            display: inline-block;
            padding: 8px 16px;
            background: rgba(200, 170, 110, 0.2);
            border: 2px solid #c8aa6e;
            border-radius: 20px;
            font-size: 18px;
            font-weight: 600;
            color: #c8aa6e;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .decoration {
            position: absolute;
            top: 20px;
            left: 20px;
            right: 20px;
            height: 4px;
            background: linear-gradient(90deg, transparent, #c8aa6e, transparent);
        }
        
        .decoration::after {
            content: '';
            position: absolute;
            bottom: -560px;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, transparent, #c8aa6e, transparent);
        }
    </style>
</head>
<body>
    <div id="champion-splash-popup">
        <div class="champion-splash"></div>
        <div class="backdrop"></div>
        <div class="decoration"></div>
        <div class="content">
            <div class="pick-number">Pick ${playerData.pick_number || 'N/A'}</div>
            <div class="player-name">${playerData.player_name || 'Unknown Player'}</div>
            <div class="team-name">${playerData.team_name || 'Unknown Team'}</div>
            <div class="champion-name">${playerData.champion_name || 'Unknown Champion'}</div>
            <div class="role-indicator">${playerData.role || 'Unknown Role'}</div>
        </div>
    </div>
</body>
</html>`;
}