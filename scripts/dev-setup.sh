#!/bin/bash

# Development setup script with automatic platform detection
# Handles Mac (ARM64) and Linux (AMD64) automatically

set -e

echo "🔧 AceApp Development Setup"
echo "=========================="

# Detect platform
ARCH=$(uname -m)
OS=$(uname -s)

echo "Detected platform: $OS ($ARCH)"

# Platform-specific Docker setup
if [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
    echo "🍎 Mac ARM64 detected - optimizing for Apple Silicon"
    export DOCKER_DEFAULT_PLATFORM=linux/arm64
elif [[ "$ARCH" == "x86_64" ]]; then
    echo "💻 x86_64 detected - using AMD64 images"
    export DOCKER_DEFAULT_PLATFORM=linux/amd64
fi

echo "Using Docker platform: ${DOCKER_DEFAULT_PLATFORM:-auto}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Build and start services
echo ""
echo "🐳 Building and starting services..."

# Use docker-compose for local development
if [[ -f "docker-compose.dev.yml" ]]; then
    echo "Using docker-compose.dev.yml for local development"
    docker-compose -f docker-compose.dev.yml up --build -d
else
    echo "Using docker-compose.yml"
    docker-compose up --build -d
fi

echo ""
echo "✅ Development environment ready!"
echo ""
echo "🌐 Services:"
echo "  - Phoenix app: http://localhost:4000"
echo "  - Screenshot service: http://localhost:3001"
echo "  - PostgreSQL: localhost:5432"
echo ""
echo "📋 Useful commands:"
echo "  - View logs: docker-compose -f docker-compose.dev.yml logs -f"
echo "  - Stop services: docker-compose -f docker-compose.dev.yml down"
echo "  - Restart: docker-compose -f docker-compose.dev.yml restart"
echo "  - Shell access: docker-compose -f docker-compose.dev.yml exec ace-app bash"
echo ""
echo "🎯 Next steps:"
echo "  1. Set up Discord OAuth credentials in .env"
echo "  2. Run database migrations: mix ecto.migrate"
echo "  3. Populate game data: mix setup_game_data"