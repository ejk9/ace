# Use platform-specific Puppeteer image for better performance
# This will automatically use ARM64 on Mac and AMD64 on Railway/CI
FROM ghcr.io/puppeteer/puppeteer:21.5.0

# Set working directory
WORKDIR /home/pptruser/app

# Copy package files for better Docker layer caching
COPY --chown=pptruser:pptruser package*.json ./

# Install dependencies and skip Puppeteer's Chrome download since we have it
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# Install dependencies with optimizations
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