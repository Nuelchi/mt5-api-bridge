#!/bin/bash
# Initialize MT5 and login directly without checking terminal_info first

set -e

echo "🚀 Initialize MT5 and Login"
echo "============================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Step 1: Try to initialize MT5 directly
echo "[1/3] Initializing MT5..."
echo "========================="
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected to RPyC server")
    
    print("   Initializing MT5...")
    if mt5.initialize():
        print("   ✅ MT5 initialized successfully")
        time.sleep(2)
        
        # Try to get terminal info after initialization
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"   ✅ Terminal info: Build {terminal_info.build}")
        else:
            print("   ⚠️  Terminal info is None, but initialization succeeded")
            print("   Continuing anyway...")
        
        sys.exit(0)
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False: {error}")
        print("   Continuing anyway (sometimes this is OK)...")
        sys.exit(0)
        
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

INIT_OK=$?
echo ""

if [ $INIT_OK -ne 0 ]; then
    echo "❌ Failed to initialize MT5"
    echo ""
    echo "💡 Checking RPyC server logs..."
    journalctl -u mt5-rpyc -n 30 --no-pager
    exit 1
fi

# Step 2: Check if already logged in
echo "[2/3] Checking login status..."
echo "=============================="
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Make sure it's initialized
    if not mt5.initialize():
        print("   Re-initializing...")
        mt5.initialize()
    
    time.sleep(1)
    
    account = mt5.account_info()
    if account:
        print(f"   ✅ Already logged in!")
        print(f"      Account: {account.login}")
        print(f"      Server: {account.server}")
        print(f"      Balance: {account.balance}")
        sys.exit(0)
    else:
        print("   ⚠️  Not logged in")
        sys.exit(1)
        
except Exception as e:
    print(f"   ⚠️  Error: {e}")
    sys.exit(1)
PYEOF

LOGIN_OK=$?
echo ""

# Step 3: Login if needed
if [ $LOGIN_OK -ne 0 ]; then
    echo "[3/3] Logging in to MT5..."
    echo "========================="
    echo "   Server: MetaQuotes-Demo"
    echo "   Login: 5042856355"
    echo ""
    
    MAX_ATTEMPTS=10
    ATTEMPT=0
    SUCCESS=false
    
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        ATTEMPT=$((ATTEMPT + 1))
        echo "   Attempt $ATTEMPT/$MAX_ATTEMPTS..."
        
        python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Initialize first
    print("   Initializing...")
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"   ⚠️  Initialize: {error}")
    else:
        print("   ✅ Initialized")
    
    time.sleep(2)
    
    # Login
    print("   Logging in...")
    authorized = mt5.login(5042856355, password="V!QzRxQ7", server="MetaQuotes-Demo")
    
    if authorized:
        print("   ✅ Login authorized")
        print("   Waiting for account info...")
        time.sleep(5)
        
        account = mt5.account_info()
        if account:
            print(f"   ✅ SUCCESS!")
            print(f"      Account: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
            print(f"      Equity: {account.equity}")
            sys.exit(0)
        else:
            print("   ⏳ Waiting longer for account info...")
            time.sleep(10)
            account = mt5.account_info()
            if account:
                print(f"   ✅ Account info retrieved!")
                print(f"      Account: {account.login}")
                print(f"      Server: {account.server}")
                sys.exit(0)
            else:
                print("   ⏳ Still waiting...")
                sys.exit(2)
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Login failed: {error}")
        sys.exit(2)
        
except Exception as e:
    print(f"   ⏳ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(2)
PYEOF

        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            SUCCESS=true
            break
        else
            echo "   ⏳ Waiting 5 seconds before retry..."
            sleep 5
        fi
    done
    
    echo ""
    
    if [ "$SUCCESS" = true ]; then
        echo "✅ Login successful!"
    else
        echo "❌ Failed to login after $MAX_ATTEMPTS attempts"
        echo ""
        echo "💡 Checking RPyC server logs for errors..."
        journalctl -u mt5-rpyc -n 50 --no-pager | tail -20
        exit 1
    fi
else
    echo "[3/3] Skipping login (already logged in)"
fi

echo ""
echo "✅ MT5 is ready and logged in!"
echo ""
echo "📋 Final Status:"
python3 <<PYEOF
from mt5linux import MetaTrader5

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    mt5.initialize()
    account = mt5.account_info()
    if account:
        print(f"   ✅ Account: {account.login}")
        print(f"   ✅ Server: {account.server}")
        print(f"   ✅ Balance: {account.balance}")
        print(f"   ✅ Equity: {account.equity}")
        print(f"   ✅ Margin: {account.margin}")
        print(f"   ✅ Free Margin: {account.margin_free}")
    else:
        print("   ⚠️  account_info() returned None")
except Exception as e:
    print(f"   ⚠️  Error: {e}")
PYEOF

echo ""
echo "🚀 Next: Run ./TEST_AND_SETUP.sh to complete setup"
echo ""

