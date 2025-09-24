#!/bin/bash

# AceApp Railway Deployment Script
# This script helps deploy the AceApp to Railway platform

set -e

echo "🚀 AceApp Railway Deployment Script"
echo "===================================="

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Please install it:"
    echo "   npm install -g @railway/cli"
    echo "   Or visit: https://docs.railway.app/develop/cli"
    exit 1
fi

# Check if user is logged in
if ! railway whoami &> /dev/null; then
    echo "❌ Not logged in to Railway. Please login:"
    echo "   railway login"
    exit 1
fi

echo "✅ Railway CLI found and authenticated"

# Create or link Railway project
echo ""
echo "🔗 Setting up Railway project..."
if [ ! -f ".railway-project-id" ]; then
    echo "No Railway project found. Creating new project..."
    railway create --name ace-app
else
    echo "Railway project already linked."
fi

# Add PostgreSQL service if not exists
echo ""
echo "🗄️  Setting up PostgreSQL database..."
railway add postgresql

# Generate secret key if not set
echo ""
echo "🔐 Setting up environment variables..."
if [ -z "$(railway variables get SECRET_KEY_BASE 2>/dev/null)" ]; then
    echo "Generating SECRET_KEY_BASE..."
    SECRET_KEY_BASE=$(mix phx.gen.secret)
    railway variables set SECRET_KEY_BASE="$SECRET_KEY_BASE"
    echo "✅ SECRET_KEY_BASE generated and set"
else
    echo "✅ SECRET_KEY_BASE already configured"
fi

# Prompt for Discord OAuth credentials
echo ""
echo "🎮 Discord OAuth Configuration"
echo "Please ensure you have created a Discord application at:"
echo "https://discord.com/developers/applications"
echo ""

if [ -z "$(railway variables get DISCORD_CLIENT_ID 2>/dev/null)" ]; then
    read -p "Enter Discord Client ID: " DISCORD_CLIENT_ID
    railway variables set DISCORD_CLIENT_ID="$DISCORD_CLIENT_ID"
    echo "✅ DISCORD_CLIENT_ID set"
else
    echo "✅ DISCORD_CLIENT_ID already configured"
fi

if [ -z "$(railway variables get DISCORD_CLIENT_SECRET 2>/dev/null)" ]; then
    read -p "Enter Discord Client Secret: " DISCORD_CLIENT_SECRET
    railway variables set DISCORD_CLIENT_SECRET="$DISCORD_CLIENT_SECRET"
    echo "✅ DISCORD_CLIENT_SECRET set"
else
    echo "✅ DISCORD_CLIENT_SECRET already configured"
fi

# Get the Railway app URL for redirect URI
APP_URL=$(railway domain)
if [ ! -z "$APP_URL" ]; then
    DISCORD_REDIRECT_URI="https://$APP_URL/auth/discord/callback"
    railway variables set DISCORD_REDIRECT_URI="$DISCORD_REDIRECT_URI"
    echo "✅ DISCORD_REDIRECT_URI set to: $DISCORD_REDIRECT_URI"
    echo ""
    echo "⚠️  IMPORTANT: Add this redirect URI to your Discord application:"
    echo "   $DISCORD_REDIRECT_URI"
else
    echo "⚠️  Railway domain not available yet. Will be set after first deployment."
fi

# Set other required environment variables
railway variables set MIX_ENV="prod"
railway variables set PHX_SERVER="true"

# Optional: Admin Discord IDs
echo ""
read -p "Enter admin Discord user IDs (comma-separated, or press Enter to skip): " ADMIN_DISCORD_IDS
if [ ! -z "$ADMIN_DISCORD_IDS" ]; then
    railway variables set ADMIN_DISCORD_IDS="$ADMIN_DISCORD_IDS"
    echo "✅ ADMIN_DISCORD_IDS set"
fi

echo ""
echo "📦 Deploying to Railway..."
railway up --detach

echo ""
echo "🎉 Deployment initiated!"
echo ""
echo "Next steps:"
echo "1. Wait for deployment to complete"
echo "2. Get your app URL: railway domain"
echo "3. Update Discord OAuth redirect URI with your Railway domain"
echo "4. Deploy screenshot service as Railway Function (see DEPLOYMENT.md)"
echo "5. Test the application"
echo ""
echo "Monitor deployment: railway logs"
echo "Open app: railway open"