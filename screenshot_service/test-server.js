const express = require('express');
const app = express();
const PORT = 3001;

console.log('Starting minimal test server...');

// Simple logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Manual JSON parsing to bypass Express issue
app.use('/capture-player-popup', (req, res, next) => {
  console.log('Manual JSON parsing...');
  let body = '';
  
  req.on('data', chunk => {
    body += chunk.toString();
    console.log('Received chunk, total length:', body.length);
  });
  
  req.on('end', () => {
    console.log('Body complete, parsing...');
    try {
      req.body = JSON.parse(body);
      console.log('JSON parsed successfully:', req.body);
      next();
    } catch (error) {
      console.error('JSON parse error:', error.message);
      return res.status(400).json({ error: 'Invalid JSON' });
    }
  });
  
  req.on('error', (error) => {
    console.error('Request error:', error.message);
    return res.status(400).json({ error: 'Request error' });
  });
});

// Simple JSON parsing for other endpoints
app.use(express.json());

// Test endpoint
app.post('/capture-player-popup', (req, res) => {
  console.log('POST endpoint hit!');
  console.log('Received request body:', req.body);
  
  const { playerData, baseUrl } = req.body;
  
  if (!playerData || !baseUrl) {
    console.log('Missing required fields');
    return res.status(400).json({ 
      error: 'Missing required fields: playerData and baseUrl' 
    });
  }
  
  console.log('All fields present, sending success response');
  res.json({ 
    status: 'success',
    message: 'Test server working',
    receivedData: req.body
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', server: 'test' });
});

app.listen(PORT, () => {
  console.log(`Test server running on port ${PORT}`);
});