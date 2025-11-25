#!/bin/bash
# Deploy latest code and test

set -e

echo "🚀 Deploying Latest Code and Testing"
echo "===================================="
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
sleep 5

if systemctl is-active --quiet mt5-api; then
    echo "✅ API service restarted"
else
    echo "❌ API service failed to start"
    journalctl -u mt5-api -n 20 --no-pager
    exit 1
fi
echo ""

# Test health endpoint
echo "[3/3] Testing API health..."
sleep 3
HEALTH=$(curl -s http://localhost:8000/health)
echo "$HEALTH" | python3 -m json.tool

MT5_CONNECTED=$(echo "$HEALTH" | python3 -c "import sys, json; data=json.load(sys.stdin); print('true' if data.get('mt5_connected') else 'false')" 2>/dev/null || echo "false")

if [ "$MT5_CONNECTED" = "true" ]; then
    echo ""
    echo "✅ API is healthy and MT5 is connected!"
    echo ""
    echo "🧪 Ready to test trading!"
    echo "   Run: python3 test_login_and_trading.py"
else
    echo ""
    echo "⚠️  MT5 is not connected"
    echo "   Run: ./CHECK_AND_LOGIN_MT5.sh"
fi

echo ""

