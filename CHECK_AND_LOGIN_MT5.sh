#!/bin/bash
# Check MT5 connection and login if needed

set -e

echo "🔍 Checking MT5 Connection"
echo "=========================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Check Docker container
echo "[1/4] Checking Docker container..."
if docker ps | grep -q mt5; then
    echo "✅ Docker container is running"
else
    echo "❌ Docker container is not running"
    echo "   Starting container..."
    docker start mt5
    sleep 10
fi
echo ""

# Test RPyC connection
echo "[2/4] Testing RPyC connection..."
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Try to initialize
    if not mt5.initialize():
        print("   ⚠️  MT5 not initialized")
        sys.exit(1)
    
    # Check if logged in
    account = mt5.account_info()
    if account:
        print(f"   ✅ MT5 is connected and logged in!")
        print(f"      Account: {account.login}")
        print(f"      Server: {account.server}")
        print(f"      Balance: {account.balance}")
        sys.exit(0)
    else:
        print("   ⚠️  MT5 initialized but not logged in")
        sys.exit(1)
        
except Exception as e:
    print(f"   ❌ Connection failed: {e}")
    sys.exit(1)
PYEOF

CONNECTION_OK=$?
echo ""

if [ $CONNECTION_OK -ne 0 ]; then
    echo "[3/4] MT5 not logged in - attempting login..."
    echo "============================================="
    
    # MT5 Credentials
    LOGIN=5042856355
    PASSWORD="V!QzRxQ7"
    SERVER="MetaQuotes-Demo"
    
    python3 <<PYEOF
from mt5linux import MetaTrader5
import time
import sys

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    print("   Initializing MT5...")
    if not mt5.initialize():
        print("   ❌ Failed to initialize MT5")
        sys.exit(1)
    
    print(f"   Logging in to account {5042856355}...")
    authorized = mt5.login(
        login=5042856355,
        password="V!QzRxQ7",
        server="MetaQuotes-Demo"
    )
    
    if not authorized:
        error = mt5.last_error()
        print(f"   ❌ Login failed: {error}")
        sys.exit(1)
    
    # Wait a moment
    time.sleep(2)
    
    # Verify login
    account = mt5.account_info()
    if account and account.login == 5042856355:
        print(f"   ✅ Login successful!")
        print(f"      Account: {account.login}")
        print(f"      Server: {account.server}")
        print(f"      Balance: {account.balance}")
        sys.exit(0)
    else:
        print("   ⚠️  Login may have succeeded but account info not available yet")
        print("   Wait 30 seconds and check again")
        sys.exit(1)
        
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

    LOGIN_OK=$?
    echo ""
    
    if [ $LOGIN_OK -eq 0 ]; then
        echo "[4/4] ✅ MT5 is now connected and logged in!"
    else
        echo "[4/4] ⚠️  Login attempt completed but verification failed"
        echo ""
        echo "💡 Try accessing MT5 Terminal via VNC:"
        echo "   http://147.182.206.223:3000"
        echo "   Log in manually if needed"
    fi
else
    echo "[3/4] ✅ MT5 is already connected"
    echo "[4/4] ✅ No action needed"
fi

echo ""
echo "🔄 Restarting API service to reconnect..."
systemctl restart mt5-api
sleep 3

echo ""
echo "✅ Complete!"
echo ""
echo "📊 Check API status:"
curl -s http://localhost:8000/health | python3 -m json.tool || echo "API may still be starting..."
echo ""

