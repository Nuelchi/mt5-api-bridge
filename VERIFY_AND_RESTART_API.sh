#!/bin/bash
# Verify MT5 connection and restart API service

set -e

echo "✅ Verifying MT5 Connection and Restarting API"
echo "=============================================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Step 1: Test MT5 connection
echo "[1/3] Testing MT5 Connection..."
echo "==============================="
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    print("   Initializing MT5...")
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False: {error}")
    else:
        print("   ✅ MT5 initialized")
    
    time.sleep(2)
    
    print("   Getting account info...")
    account = mt5.account_info()
    if account:
        print(f"   ✅ SUCCESS! MT5 is connected and logged in!")
        print(f"      Account: {account.login}")
        print(f"      Server: {account.server}")
        print(f"      Balance: {account.balance}")
        print(f"      Equity: {account.equity}")
        sys.exit(0)
    else:
        print("   ⚠️  account_info() returned None")
        print("   Waiting 5 seconds and retrying...")
        time.sleep(5)
        account = mt5.account_info()
        if account:
            print(f"   ✅ Account info retrieved!")
            print(f"      Account: {account.login}")
            sys.exit(0)
        else:
            print("   ❌ Still no account info")
            sys.exit(1)
            
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

CONNECTION_OK=$?
echo ""

if [ $CONNECTION_OK -ne 0 ]; then
    echo "❌ MT5 connection test failed"
    echo "   Please ensure MT5 Terminal is logged in"
    exit 1
fi

# Step 2: Restart API service
echo "[2/3] Restarting API service..."
echo "==============================="
systemctl restart mt5-api
sleep 5

if systemctl is-active --quiet mt5-api; then
    echo "   ✅ API service restarted"
else
    echo "   ❌ API service failed to start"
    echo "   Checking logs..."
    journalctl -u mt5-api -n 20 --no-pager
    exit 1
fi
echo ""

# Step 3: Test API health endpoint
echo "[3/3] Testing API health endpoint..."
echo "===================================="
sleep 3

HEALTH_RESPONSE=$(curl -s http://localhost:8000/health)
echo "$HEALTH_RESPONSE" | python3 -m json.tool || echo "$HEALTH_RESPONSE"

MT5_CONNECTED=$(echo "$HEALTH_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print('true' if data.get('mt5_connected') else 'false')" 2>/dev/null || echo "false")

if [ "$MT5_CONNECTED" = "true" ]; then
    echo ""
    echo "   ✅ API shows MT5 is connected!"
else
    echo ""
    echo "   ⚠️  API shows MT5 is not connected yet"
    echo "   Wait a few more seconds and check again"
fi

echo ""
echo "✅ Verification complete!"
echo ""
echo "🌐 Test the API:"
echo "   python3 test_api_with_auth.py https://trade.trainflow.dev"
echo ""

