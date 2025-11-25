#!/bin/bash
# Fix RPC port in .env file

set -e

echo "🔧 Fixing RPC Port Configuration"
echo "================================="
echo ""

cd /opt/mt5-api-bridge

# Check current .env
echo "[1/3] Checking current .env configuration..."
if [ -f .env ]; then
    echo "   Current MT5_RPC_PORT:"
    grep MT5_RPC_PORT .env || echo "   (not set)"
    echo "   Current MT5_RPC_HOST:"
    grep MT5_RPC_HOST .env || echo "   (not set)"
else
    echo "   .env file not found"
fi
echo ""

# Update .env
echo "[2/3] Updating .env file..."
if [ -f .env ]; then
    # Update or add MT5_RPC_PORT
    if grep -q "MT5_RPC_PORT" .env; then
        sed -i 's/^MT5_RPC_PORT=.*/MT5_RPC_PORT=8001/' .env
        echo "   ✅ Updated MT5_RPC_PORT=8001"
    else
        echo "MT5_RPC_PORT=8001" >> .env
        echo "   ✅ Added MT5_RPC_PORT=8001"
    fi
    
    # Update or add MT5_RPC_HOST
    if grep -q "MT5_RPC_HOST" .env; then
        sed -i 's/^MT5_RPC_HOST=.*/MT5_RPC_HOST=localhost/' .env
        echo "   ✅ Updated MT5_RPC_HOST=localhost"
    else
        echo "MT5_RPC_HOST=localhost" >> .env
        echo "   ✅ Added MT5_RPC_HOST=localhost"
    fi
else
    echo "   ⚠️  .env file not found - creating it"
    cat >> .env <<EOF
MT5_RPC_HOST=localhost
MT5_RPC_PORT=8001
EOF
    echo "   ✅ Created .env with RPC settings"
fi
echo ""

# Restart API service
echo "[3/3] Restarting API service..."
systemctl restart mt5-api
sleep 3

if systemctl is-active --quiet mt5-api; then
    echo "   ✅ API service restarted"
else
    echo "   ❌ API service failed to start"
    journalctl -u mt5-api -n 20 --no-pager
    exit 1
fi
echo ""

# Test connection
echo "🧪 Testing connection..."
sleep 2
HEALTH=$(curl -s http://localhost:8000/health)
if echo "$HEALTH" | grep -q '"mt5_connected":true'; then
    echo "   ✅ MT5 is now connected!"
    echo "$HEALTH" | python3 -m json.tool
else
    echo "   ⚠️  MT5 connection status:"
    echo "$HEALTH" | python3 -m json.tool
fi

echo ""
echo "✅ Fix complete!"
echo ""

