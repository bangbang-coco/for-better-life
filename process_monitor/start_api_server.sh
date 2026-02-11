#!/bin/bash
#
# Monitor API Server Quick Start Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting Monitor API Server..."
echo ""

# Check Docker installation
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed."
    echo "   Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo "❌ Error: Docker Compose is not installed."
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Error: Docker is not running."
    echo "   Please start Docker."
    exit 1
fi

# Check port usage
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Warning: Port 8080 is already in use."
    echo "   To use a different port, modify docker-compose.yml."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run Docker Compose
echo "📦 Building Docker image and starting container..."
if docker compose version &> /dev/null 2>&1; then
    docker compose up -d --build
else
    docker-compose up -d --build
fi

echo ""
echo "✅ Monitor API Server started successfully!"
echo ""
echo "📍 API endpoint: http://localhost:8080/"
echo "📍 Web interface:  http://localhost:8080/"
echo "📍 Health check:       http://localhost:8080/health"
echo ""
echo "📊 View logs:"
if docker compose version &> /dev/null 2>&1; then
    echo "   docker compose logs -f"
else
    echo "   docker-compose logs -f"
fi
echo ""
echo "🛑 Stop server:"
if docker compose version &> /dev/null 2>&1; then
    echo "   docker compose down"
else
    echo "   docker-compose down"
fi
echo ""
echo "🧪 Test command:"
echo "   ./monitor_salt.sh compare --json --api-url http://localhost:8080/"
echo ""
