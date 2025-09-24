# League of Legends Draft Tool - Production Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the League of Legends Draft Tool to production hosting platforms, with detailed comparisons and recommendations for different deployment scenarios.

**Current Tech Stack:**
- **Backend**: Phoenix LiveView (Elixir/OTP)
- **Database**: PostgreSQL with real-time features
- **Screenshot Service**: Node.js Puppeteer service (Docker container)
- **File Storage**: Team logo uploads (10MB, WebP/PNG/JPG/SVG)
- **Real-time**: Phoenix PubSub for LiveView updates
- **Authentication**: Discord OAuth with session management

## Platform Comparison & Analysis

### 🚀 Railway (Recommended for This Project)

**Why Railway is Ideal for This Stack:**

✅ **Strengths for Our Use Case:**
- **Excellent Phoenix LiveView Support**: Native Elixir buildpack with WebSocket optimization
- **Serverless Functions**: Perfect for our Node.js screenshot service
- **Integrated PostgreSQL**: Managed database with connection pooling
- **Docker Support**: Can deploy both Phoenix app and screenshot service
- **GitHub Integration**: Automatic deployments from repository
- **Environment Variables**: Secure secrets management
- **Custom Domains**: Easy SSL certificate management
- **Cost Effective**: Pay-as-you-scale pricing model

✅ **Perfect Fit for Screenshot Service:**
- **Railway Functions**: Can deploy our Node.js Puppeteer service as a serverless function
- **Docker Services**: Alternative deployment as a Docker container alongside Phoenix
- **Internal Networking**: Services can communicate via internal URLs
- **Automatic Scaling**: Screenshot service scales based on demand

⚠️ **Considerations:**
- Newer platform (less mature than some alternatives)
- Pricing can scale quickly with high usage
- Limited to specific regions

**Railway Services Architecture:**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Phoenix App   │────│   PostgreSQL     │    │  Screenshot     │
│   (Web Service) │    │   (Database)     │    │  Service        │
│   Port: $PORT   │    │   Port: 5432     │    │  (Function)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 🛩️ Fly.io 

✅ **Strengths:**
- **Elixir/Phoenix Specialized**: Excellent performance for Phoenix apps
- **Global Edge Network**: Low latency worldwide
- **Built-in PostgreSQL**: Fly Postgres with clustering
- **Docker Native**: Excellent Docker support
- **Live Migrations**: Hot code deployment
- **IPv6 Support**: Modern networking

❌ **Challenges for Our Screenshot Service:**
- **No Serverless Functions**: Would need to run screenshot service as separate app
- **Resource Management**: Screenshot service would need dedicated resources
- **Complexity**: Managing multiple Fly apps for different services
- **Cost**: Running screenshot service 24/7 even when not in use

### 🎯 Render

✅ **Strengths:**
- **Free Tier Available**: Good for testing and small deployments
- **Managed PostgreSQL**: Reliable database hosting
- **Auto-deploys**: GitHub integration
- **CDN Integration**: Good for static assets

❌ **Limitations:**
- **WebSocket Constraints**: Limited on free tier (affects LiveView)
- **Cold Starts**: Free tier services sleep after inactivity
- **Screenshot Service**: Would need separate deployment, less integrated

### 🌊 DigitalOcean App Platform

✅ **Strengths:**
- **Reliable Infrastructure**: Proven platform
- **Managed Databases**: PostgreSQL with backups
- **Spaces**: S3-compatible storage for files
- **Competitive Pricing**: Good value proposition

❌ **Considerations:**
- **Phoenix Support**: Good but not specialized for Elixir
- **Screenshot Service**: Would need containerized deployment
- **Setup Complexity**: More manual configuration required

## Railway Deployment Guide

### Prerequisites

1. **Railway Account**: Sign up at [railway.app](https://railway.app)
2. **GitHub Repository**: Your code should be in a GitHub repository
3. **Discord Application**: OAuth app configured for production domain
4. **Domain Name** (Optional): For custom domain instead of railway.app subdomain

### Step 1: Project Setup

1. **Connect Repository**:
   ```bash
   # Login to Railway CLI (optional)
   npm install -g @railway/cli
   railway login
   
   # Or use Railway dashboard at railway.app
   ```

2. **Create New Project**:
   - Go to [railway.app/new](https://railway.app/new)
   - Select "Deploy from GitHub repo"
   - Choose your repository
   - Railway will detect it as an Elixir project

### Step 2: Environment Configuration

**Required Environment Variables:**

```bash
# Database (Railway will provide these automatically)
DATABASE_URL=postgresql://user:pass@host:port/db
ECTO_IPV6=true

# Phoenix Configuration
SECRET_KEY_BASE=<generate-with-mix-phx.gen.secret>
PHX_HOST=your-app-name.up.railway.app
PORT=4000

# Discord OAuth
DISCORD_CLIENT_ID=your_discord_client_id
DISCORD_CLIENT_SECRET=your_discord_client_secret
DISCORD_REDIRECT_URI=https://your-app-name.up.railway.app/auth/discord/callback

# Admin Configuration
ADMIN_DISCORD_IDS=your_discord_user_id_here

# Screenshot Service Configuration
SCREENSHOT_SERVICE_URL=https://your-screenshot-service.up.railway.app
BASE_URL=https://your-app-name.up.railway.app

# Production Configuration
MIX_ENV=prod
ERL_AFLAGS="-proto_dist inet6_tcp"
```

### Step 3: Database Setup

1. **Add PostgreSQL Service**:
   - In Railway dashboard, click "Add Service"
   - Select "PostgreSQL"
   - Railway automatically provides connection details

2. **Database Variables** (Auto-configured):
   ```bash
   PGHOST=containers-us-west-xxx.railway.app
   PGPORT=5432
   PGDATABASE=railway
   PGUSER=postgres
   PGPASSWORD=<generated>
   DATABASE_URL=postgresql://postgres:<password>@<host>:5432/railway
   ```

### Step 4: Phoenix App Configuration

1. **Update `config/runtime.exs`** for Railway compatibility:
   ```elixir
   import Config
   
   if config_env() == :prod do
     database_url =
       System.get_env("DATABASE_URL") ||
         raise """
         environment variable DATABASE_URL is missing.
         """
   
     maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []
   
     config :ace_app, AceApp.Repo,
       url: database_url,
       pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
       socket_options: maybe_ipv6
   
     # Phoenix Endpoint Configuration
     host = System.get_env("PHX_HOST") || "localhost"
     port = String.to_integer(System.get_env("PORT") || "4000")
   
     config :ace_app, AceAppWeb.Endpoint,
       url: [host: host, port: 443, scheme: "https"],
       http: [
         ip: {0, 0, 0, 0, 0, 0, 0, 0},
         port: port
       ],
       secret_key_base: System.get_env("SECRET_KEY_BASE"),
       server: true
       
     # Discord OAuth Configuration
     config :ace_app,
       discord_client_id: System.get_env("DISCORD_CLIENT_ID"),
       discord_client_secret: System.get_env("DISCORD_CLIENT_SECRET"),
       discord_redirect_uri: System.get_env("DISCORD_REDIRECT_URI"),
       admin_discord_ids: System.get_env("ADMIN_DISCORD_IDS"),
       screenshot_service_url: System.get_env("SCREENSHOT_SERVICE_URL"),
       base_url: System.get_env("BASE_URL")
   end
   ```

2. **Create/Update `Dockerfile`** (if needed):
   ```dockerfile
   # Build stage
   FROM hexpm/elixir:1.15.7-erlang-26.1.2-alpine-3.18.4 AS build
   
   # Install build dependencies
   RUN apk add --no-cache build-base npm git python3
   
   # Prepare build dir
   WORKDIR /app
   
   # Install hex + rebar
   RUN mix local.hex --force && \
       mix local.rebar --force
   
   # Set build ENV
   ENV MIX_ENV=prod
   
   # Install mix dependencies
   COPY mix.exs mix.lock ./
   RUN mix deps.get --only prod
   RUN mkdir config
   
   # Copy compile-time config
   COPY config/config.exs config/prod.exs config/runtime.exs config/
   RUN mix deps.compile
   
   # Install npm dependencies and build assets
   COPY assets/package.json assets/package-lock.json ./assets/
   RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error
   
   # Copy all application files
   COPY . .
   
   # Compile and build assets
   RUN mix assets.deploy
   RUN mix compile
   
   # Build release
   RUN mix release
   
   # Runtime stage
   FROM alpine:3.18.4 AS app
   
   RUN apk add --no-cache openssl ncurses-libs
   
   WORKDIR /app
   
   RUN addgroup -g 1001 -S phoenix && \
       adduser -S phoenix -u 1001 -G phoenix
   
   USER phoenix:phoenix
   
   COPY --from=build --chown=phoenix:phoenix /app/_build/prod/rel/ace_app ./
   
   EXPOSE 4000
   
   CMD ["./bin/ace_app", "start"]
   ```

3. **Create `railway.toml`** (optional configuration):
   ```toml
   [build]
   builder = "dockerfile"
   
   [deploy]
   startCommand = "./bin/ace_app eval \"AceApp.Release.migrate\" && ./bin/ace_app start"
   healthcheckPath = "/health"
   healthcheckTimeout = 100
   restartPolicyType = "on_failure"
   ```

### Step 5: Screenshot Service Deployment

**Option 1: Railway Function (Recommended)**

1. **Create `screenshot-function/` directory** in your repo:
   ```bash
   mkdir screenshot-function
   cd screenshot-function
   ```

2. **Create `package.json`**:
   ```json
   {
     "name": "screenshot-function",
     "version": "1.0.0",
     "main": "index.js",
     "dependencies": {
       "puppeteer": "^21.0.0",
       "express": "^4.18.2"
     },
     "engines": {
       "node": "18"
     }
   }
   ```

3. **Create `index.js`**:
   ```javascript
   const express = require('express');
   const puppeteer = require('puppeteer');
   
   const app = express();
   const PORT = process.env.PORT || 3000;
   
   app.use(express.json());
   
   app.post('/screenshot', async (req, res) => {
     try {
       const { url, selector, filename } = req.body;
       
       const browser = await puppeteer.launch({
         headless: 'new',
         args: ['--no-sandbox', '--disable-setuid-sandbox']
       });
       
       const page = await browser.newPage();
       await page.goto(url, { waitUntil: 'networkidle0' });
       
       const element = selector ? await page.$(selector) : page;
       const screenshot = await element.screenshot({
         type: 'png',
         fullPage: !selector
       });
       
       await browser.close();
       
       res.set({
         'Content-Type': 'image/png',
         'Content-Disposition': `attachment; filename="${filename || 'screenshot.png'}"`
       });
       
       res.send(screenshot);
     } catch (error) {
       console.error('Screenshot error:', error);
       res.status(500).json({ error: error.message });
     }
   });
   
   app.get('/health', (req, res) => {
     res.json({ status: 'ok' });
   });
   
   app.listen(PORT, '0.0.0.0', () => {
     console.log(`Screenshot service running on port ${PORT}`);
   });
   ```

4. **Deploy as Separate Railway Service**:
   - In Railway dashboard, add new service
   - Connect same GitHub repo
   - Set root directory to `screenshot-function/`
   - Railway will detect Node.js and deploy automatically

**Option 2: Docker Service (Alternative)**

1. **Create `screenshot-service.dockerfile`**:
   ```dockerfile
   FROM node:18-alpine
   
   # Install Chrome dependencies
   RUN apk add --no-cache \
     chromium \
     nss \
     freetype \
     freetype-dev \
     harfbuzz \
     ca-certificates \
     ttf-freefont
   
   # Tell Puppeteer to use installed Chromium
   ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
       PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
   
   WORKDIR /app
   COPY screenshot_service/package*.json ./
   RUN npm ci --production
   
   COPY screenshot_service/ .
   
   EXPOSE 3000
   CMD ["node", "index.js"]
   ```

### Step 6: Database Migration and Setup

1. **Create Release Module** (`lib/ace_app/release.ex`):
   ```elixir
   defmodule AceApp.Release do
     @moduledoc """
     Used for executing DB release tasks when run in production without Mix
     installed.
     """
     @app :ace_app
   
     def migrate do
       load_app()
   
       for repo <- repos() do
         {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
       end
     end
   
     def rollback(repo, version) do
       load_app()
       {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
     end
   
     def setup_game_data do
       load_app()
       
       for repo <- repos() do
         {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo ->
           # Run champion and skin data population
           Mix.Task.run("setup_game_data", ["--skip-migration"])
         end)
       end
     end
   
     defp repos do
       Application.fetch_env!(@app, :ecto_repos)
     end
   
     defp load_app do
       Application.load(@app)
     end
   end
   ```

2. **Update Deploy Command** in Railway:
   ```bash
   ./bin/ace_app eval "AceApp.Release.migrate()" && ./bin/ace_app eval "AceApp.Release.setup_game_data()" && ./bin/ace_app start
   ```

### Step 7: Domain and SSL Setup

1. **Custom Domain** (Optional):
   - In Railway dashboard, go to Settings
   - Add custom domain: `yourdomain.com`
   - Update DNS CNAME record to point to Railway

2. **SSL Certificate**:
   - Railway automatically provides SSL for custom domains
   - Update Discord OAuth redirect URI to use HTTPS

3. **Update Environment Variables**:
   ```bash
   PHX_HOST=yourdomain.com
   DISCORD_REDIRECT_URI=https://yourdomain.com/auth/discord/callback
   BASE_URL=https://yourdomain.com
   ```

### Step 8: Deployment and Testing

1. **Deploy**:
   - Push changes to GitHub repository
   - Railway automatically detects changes and deploys
   - Monitor deployment logs in Railway dashboard

2. **Test Deployment**:
   ```bash
   # Test main application
   curl https://your-app.up.railway.app/health
   
   # Test screenshot service
   curl https://your-screenshot-service.up.railway.app/health
   
   # Test database connection (check logs)
   ```

3. **Monitor Services**:
   - Railway dashboard shows service health
   - Check application logs for any errors
   - Verify Discord OAuth is working

## Post-Deployment Optimization

### Performance Monitoring

1. **Add Health Checks**:
   ```elixir
   # In router.ex
   get "/health", HealthController, :index
   
   # Create health controller
   defmodule AceAppWeb.HealthController do
     use AceAppWeb, :controller
   
     def index(conn, _params) do
       # Check database connectivity
       case AceApp.Repo.query("SELECT 1") do
         {:ok, _} -> json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
         {:error, _} -> 
           conn
           |> put_status(503)
           |> json(%{status: "error", message: "Database unavailable"})
       end
     end
   end
   ```

2. **Configure Monitoring**:
   - Railway provides basic metrics
   - Consider adding external monitoring (e.g., Pingdom, UptimeRobot)

### Cost Optimization

1. **Resource Monitoring**:
   - Monitor Railway usage dashboard
   - Set up billing alerts
   - Optimize database connections (`POOL_SIZE`)

2. **Scaling Configuration**:
   ```bash
   # Environment variables for optimization
   POOL_SIZE=10
   ERL_MAX_PROCESSES=1048576
   ERL_MAX_ETS_TABLES=32768
   ```

### Security Hardening

1. **Environment Variables**:
   - Ensure all secrets are in Railway environment variables
   - Never commit secrets to repository
   - Use strong `SECRET_KEY_BASE`

2. **Database Security**:
   - Railway PostgreSQL includes SSL by default
   - Restrict database access to Railway network only

## Troubleshooting Common Issues

### 1. LiveView WebSocket Issues
```bash
# Ensure proper IPv6 configuration
ECTO_IPV6=true

# Check endpoint configuration in runtime.exs
http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port]
```

### 2. Screenshot Service Connection
```bash
# Verify internal network communication
SCREENSHOT_SERVICE_URL=https://screenshot-service-name.up.railway.app

# Test from Phoenix app console
HTTPoison.get("#{System.get_env("SCREENSHOT_SERVICE_URL")}/health")
```

### 3. Database Connection Issues
```bash
# Check connection pool settings
POOL_SIZE=10
DATABASE_POOL_SIZE=10

# Verify DATABASE_URL format
DATABASE_URL=postgresql://user:pass@host:port/dbname
```

### 4. Static Asset Issues
```bash
# Ensure assets are compiled in production
mix assets.deploy

# Check static file serving in endpoint config
plug Plug.Static, at: "/", from: :ace_app
```

## Maintenance and Updates

### 1. Automated Deployments
- Railway automatically deploys on GitHub pushes
- Configure deployment branch in Railway settings
- Use staging environment for testing

### 2. Database Backups
```bash
# Railway provides automatic backups
# Manual backup via Railway CLI:
railway db backup
```

### 3. Monitoring Checklist
- [ ] Application health endpoint responding
- [ ] Database connectivity working
- [ ] Screenshot service operational
- [ ] Discord OAuth functioning
- [ ] File uploads working
- [ ] Real-time features operational
- [ ] Performance metrics within limits

## Cost Estimation

### Railway Pricing Structure (as of 2024):
- **Hobby Plan**: $5/month - Good for development and testing
- **Pro Plan**: $20/month + usage - Recommended for production
- **Usage-Based**: CPU, RAM, Network, Storage costs

### Estimated Monthly Costs:
- **Small Tournament Use** (1-5 concurrent drafts): $20-40/month
- **Medium Tournament Use** (5-20 concurrent drafts): $40-80/month
- **Large Tournament Use** (20+ concurrent drafts): $80-150/month

### Cost Optimization Tips:
1. **Scale Down During Off-Peak**: Use Railway's scaling features
2. **Optimize Database Connections**: Reduce POOL_SIZE when possible
3. **Monitor Screenshot Service Usage**: Only scale when needed
4. **Use Efficient Queries**: Optimize database performance

## Alternative Deployment Options

If Railway doesn't meet your needs, here are the deployment steps for alternatives:

### Quick Deploy to Fly.io
```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Initialize Fly app
fly launch --no-deploy

# Configure secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set DISCORD_CLIENT_ID=your_client_id
# ... other secrets

# Deploy
fly deploy
```

### Quick Deploy to Render
1. Connect GitHub repository at render.com
2. Choose "Web Service"
3. Configure environment variables
4. Deploy with build command: `mix assets.deploy && mix phx.digest`
5. Start command: `mix phx.server`

This comprehensive guide should get your League of Legends Draft Tool deployed to production on Railway with all services working correctly. The screenshot service integration via Railway Functions makes it an ideal choice for your specific tech stack.