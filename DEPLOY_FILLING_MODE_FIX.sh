#!/bin/bash
# Deploy the filling mode fix to VPS

set -e

echo "🚀 Deploying Filling Mode Fix"
echo "=============================="
echo ""

cd /opt/mt5-api-bridge

# Pull latest changes
echo "[1/3] Pulling latest changes..."
git pull
echo "✅ Code updated"
echo ""

# Restart API service
echo "[2/3] Restarting API service..."
systemctl restart mt5-api
sleep 3

if systemctl is-active --quiet mt5-api; then
    echo "✅ API service restarted"
else
    echo "❌ API service failed to start"
    echo "Checking logs..."
    journalctl -u mt5-api -n 20 --no-pager
    exit 1
fi
echo ""

# Test health endpoint
echo "[3/3] Testing API..."
sleep 2
HEALTH=$(curl -s http://localhost:8000/health)
if echo "$HEALTH" | grep -q "healthy"; then
    echo "✅ API is healthy"
else
    echo "⚠️  API health check failed"
    echo "$HEALTH"
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "💡 The filling mode fix is now deployed."
echo "   The API will now automatically detect the correct filling mode for each broker."
echo ""

