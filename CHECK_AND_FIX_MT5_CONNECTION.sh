#!/bin/bash
# Check and fix MT5 connection issue

set -e

echo "🔍 Checking MT5 Connection"
echo "=========================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Step 1: Check Docker container
echo "[1/4] Checking Docker MT5 container..."
echo "======================================"
if docker ps | grep -q mt5; then
    echo "✅ Docker container is running"
    docker ps | grep mt5
else
    echo "❌ Docker container is not running"
    echo "   Starting container..."
    docker start mt5
    sleep 10
fi
echo ""

# Step 2: Test RPyC connection
echo "[2/4] Testing RPyC connection..."
echo "================================"
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    account = mt5.account_info()
    if account:
        print(f"✅ MT5 is connected!")
        print(f"   Account: {account.login}")
        print(f"   Server: {account.server}")
        print(f"   Balance: {account.balance}")
        sys.exit(0)
    else:
        print("⚠️  Connected but account_info() returned None")
        print("   MT5 Terminal may not be logged in")
        sys.exit(1)
except Exception as e:
    print(f"❌ Connection failed: {e}")
    sys.exit(1)
PYEOF

CONNECTION_OK=$?
echo ""

# Step 3: Check API service
echo "[3/4] Checking API service..."
echo "============================="
if systemctl is-active --quiet mt5-api; then
    echo "✅ API service is running"
    
    # Check API logs for MT5 connection errors
    echo "   Recent API logs:"
    journalctl -u mt5-api -n 10 --no-pager | grep -i "mt5\|connection\|error" || echo "   (No relevant logs)"
else
    echo "❌ API service is not running"
    echo "   Starting service..."
    systemctl start mt5-api
    sleep 3
fi
echo ""

# Step 4: Restart API service to reconnect
if [ $CONNECTION_OK -eq 0 ]; then
    echo "[4/4] Restarting API service to reconnect to MT5..."
    echo "=================================================="
    systemctl restart mt5-api
    sleep 5
    
    echo "   Testing API health endpoint..."
    curl -s http://localhost:8000/health | python3 -m json.tool || echo "   API may still be starting..."
else
    echo "[4/4] MT5 connection issue detected"
    echo "=================================="
    echo "   The RPyC connection test failed."
    echo "   This could mean:"
    echo "   1. MT5 Terminal in Docker is not logged in"
    echo "   2. RPyC server is not responding"
    echo ""
    echo "   Check Docker logs: docker logs mt5 --tail 50"
    echo "   Or access MT5 GUI: http://147.182.206.223:3000"
fi

echo ""
echo "✅ Check complete!"
echo ""

