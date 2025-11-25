#!/bin/bash
# Clean up old MT5 setup and set up Docker

set -e

echo "🧹 Cleaning up old MT5 setup and setting up Docker"
echo "=================================================="
echo ""

cd /opt/mt5-api-bridge

# Step 1: Stop old RPyC server
echo "[1/5] Stopping old RPyC server..."
echo "================================"
if systemctl is-active --quiet mt5-rpyc; then
    echo "   Stopping mt5-rpyc service..."
    systemctl stop mt5-rpyc
    systemctl disable mt5-rpyc
    echo "   ✅ RPyC server stopped"
else
    echo "   ✅ RPyC server not running"
fi

# Check for any process using port 8001
if lsof -i :8001 2>/dev/null | grep -q LISTEN; then
    echo "   Found process using port 8001, killing it..."
    lsof -ti :8001 | xargs kill -9 2>/dev/null || true
    sleep 2
    echo "   ✅ Port 8001 freed"
else
    echo "   ✅ Port 8001 is free"
fi
echo ""

# Step 2: Stop old MT5 Terminal process
echo "[2/5] Stopping old MT5 Terminal process..."
echo "=========================================="
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "   Stopping MT5 Terminal..."
    pkill -f "terminal64.exe" || true
    sleep 2
    echo "   ✅ MT5 Terminal stopped"
else
    echo "   ✅ No MT5 Terminal process running"
fi
echo ""

# Step 3: Stop old MT5 API service
echo "[3/5] Stopping old MT5 API service..."
echo "====================================="
if systemctl is-active --quiet mt5-api; then
    echo "   Stopping mt5-api service..."
    systemctl stop mt5-api
    echo "   ✅ MT5 API service stopped"
else
    echo "   ✅ MT5 API service not running"
fi
echo ""

# Step 4: Stop and remove Docker container if exists
echo "[4/5] Cleaning up Docker containers..."
echo "======================================"
if docker ps -a | grep -q mt5; then
    echo "   Stopping and removing existing MT5 container..."
    docker stop mt5 2>/dev/null || true
    docker rm mt5 2>/dev/null || true
    echo "   ✅ Docker container cleaned up"
else
    echo "   ✅ No existing Docker container"
fi
echo ""

# Step 5: Verify ports are free
echo "[5/5] Verifying ports are free..."
echo "================================="
if lsof -i :8001 2>/dev/null | grep -q LISTEN; then
    echo "   ⚠️  Port 8001 is still in use:"
    lsof -i :8001
    echo "   Trying to free it..."
    lsof -ti :8001 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

if lsof -i :3000 2>/dev/null | grep -q LISTEN; then
    echo "   ⚠️  Port 3000 is in use:"
    lsof -i :3000
    echo "   (This is OK if it's the Docker container)"
else
    echo "   ✅ Port 3000 is free"
fi

if ! lsof -i :8001 2>/dev/null | grep -q LISTEN; then
    echo "   ✅ Port 8001 is free"
else
    echo "   ❌ Port 8001 is still in use - please check manually"
    exit 1
fi
echo ""

echo "✅ Cleanup complete!"
echo ""
echo "🚀 Now running Docker setup..."
echo ""

# Run the Docker setup script
./SETUP_DOCKER_MT5.sh

