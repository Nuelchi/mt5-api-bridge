#!/bin/bash
# Check if server has latest code and update if needed

set -e

echo "🔍 Checking Server Code Status"
echo "================================"
echo ""

cd /opt/mt5-api-bridge

echo "[1/4] Checking git status..."
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Code is up to date (commit: $LOCAL)"
else
    echo "⚠️  Code is outdated!"
    echo "   Local:  $LOCAL"
    echo "   Remote: $REMOTE"
    echo ""
    echo "[2/4] Pulling latest code..."
    git pull origin main
    echo "✅ Code updated"
fi

echo ""
echo "[3/4] Verifying symbol_info_tick usage..."
if grep -q "symbol_info_tick" mt5_api_bridge.py; then
    echo "✅ Using symbol_info_tick() - code is correct"
else
    echo "❌ NOT using symbol_info_tick() - code needs update!"
    exit 1
fi

echo ""
echo "[4/4] Restarting API service..."
systemctl restart mt5-api
sleep 5

echo ""
echo "✅ Server updated and restarted!"
echo ""
echo "🧪 Test with: python3 test_login_and_trading.py"

