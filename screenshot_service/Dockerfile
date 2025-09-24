# Use a pre-built image with Puppeteer and Chrome already installed
FROM ghcr.io/puppeteer/puppeteer:21.5.0
# Use ARM64-compatible Puppeteer image
FROM --platform=linux/arm64 ghcr.io/puppeteer/puppeteer:21.5.0

# Set working directory
WORKDIR /home/pptruser/app

# Copy package filesbetter Docker layer caching
COPY --chown=pptruser:pptruser package*.json ./

# Install only our specific dependencies (Puppeteer is already available)

# Install dependencies and skip Puppeteer's Chrome download since we have it
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# Install dependencies with optimizations
# Use npm install instead of npm installinstallinstall for better caching
# Set cache directory to a volume that can be reused
ENV NPM_CONFIG_CACHE=/tmp/.npm
RUN npm install --only=production --silent --no-audit --no-fund

# Copy application code
COPY --chown=pptruser:pptruser . .

# Create screenshots directory
RUN mkdir -p /home/pptruser/app/screenshots

# Expose port
EXPOSE 3001

# Start the service
CMD ["npm", "start"]