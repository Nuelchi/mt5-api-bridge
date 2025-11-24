#!/bin/bash
# Wait for MT5 Terminal to be fully ready, then login

set -e

echo "⏳ Waiting for MT5 Terminal to be Ready"
echo "======================================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Step 1: Wait for terminal_info() to work
echo "[1/3] Waiting for MT5 Terminal to initialize..."
echo "==============================================="
echo "   This may take 30-60 seconds..."
echo ""

MAX_WAIT=60
WAITED=0
TERMINAL_READY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    terminal_info = mt5.terminal_info()
    if terminal_info and terminal_info.build:
        print(f"   ✅ Terminal ready! Build: {terminal_info.build}")
        sys.exit(0)
    else:
        print(f"   ⏳ Waiting... ({sys.argv[1] if len(sys.argv) > 1 else 0}s)")
        sys.exit(1)
except Exception as e:
    print(f"   ⏳ Waiting... ({sys.argv[1] if len(sys.argv) > 1 else 0}s) - {str(e)[:50]}")
    sys.exit(1)
PYEOF

    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        TERMINAL_READY=true
        break
    fi
    
    WAITED=$((WAITED + 5))
    echo "   (Waited $WAITED seconds so far...)"
    sleep 5
done

echo ""

if [ "$TERMINAL_READY" = false ]; then
    echo "⚠️  MT5 Terminal did not become ready after $MAX_WAIT seconds"
    echo ""
    echo "💡 Trying to restart MT5 Terminal..."
    
    # Kill existing process
    pkill -f "terminal64.exe" || true
    sleep 5
    
    # Start fresh
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    
    if [ -f "$MT5_EXE" ]; then
        echo "   Starting MT5 Terminal..."
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        sleep 20
        
        # Wait again
        WAITED=0
        while [ $WAITED -lt 60 ]; do
            python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    terminal_info = mt5.terminal_info()
    if terminal_info and terminal_info.build:
        print(f"   ✅ Terminal ready after restart! Build: {terminal_info.build}")
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
PYEOF

            if [ $? -eq 0 ]; then
                TERMINAL_READY=true
                break
            fi
            
            WAITED=$((WAITED + 5))
            sleep 5
        done
    fi
fi

if [ "$TERMINAL_READY" = false ]; then
    echo "❌ Failed to get MT5 Terminal ready"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check MT5 Terminal process: ps aux | grep terminal64"
    echo "   2. Check RPyC server: systemctl status mt5-rpyc"
    echo "   3. Check RPyC logs: journalctl -u mt5-rpyc -n 50"
    echo "   4. Try restarting RPyC: systemctl restart mt5-rpyc"
    exit 1
fi

echo ""

# Step 2: Check login status
echo "[2/3] Checking login status..."
echo "=============================="
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
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
    print(f"   ⚠️  Not logged in: {e}")
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
    
    MAX_ATTEMPTS=15
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
    
    # Initialize
    print("   Initializing...")
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"   ⚠️  Initialize: {error}")
    else:
        print("   ✅ Initialized")
    
    time.sleep(3)
    
    # Login
    print("   Logging in...")
    authorized = mt5.login(5042856355, password="V!QzRxQ7", server="MetaQuotes-Demo")
    
    if authorized:
        print("   ✅ Login authorized, waiting for account info...")
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
            # Try again after more time
            print("   ⏳ Waiting longer for account info...")
            time.sleep(10)
            account = mt5.account_info()
            if account:
                print(f"   ✅ Account info retrieved!")
                print(f"      Account: {account.login}")
                sys.exit(0)
            else:
                print("   ⏳ Still waiting...")
                sys.exit(2)  # Retry
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Login failed: {error}")
        sys.exit(2)  # Retry
        
except TimeoutError:
    print("   ⏳ Timeout - retrying...")
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
        echo "💡 The MT5 Terminal might need manual intervention:"
        echo "   1. Check if MT5 Terminal GUI is accessible (may need VNC)"
        echo "   2. Try restarting MT5 Terminal: pkill -f terminal64.exe && sleep 5 && wine 'C:\\Program Files\\MetaTrader 5\\terminal64.exe'"
        echo "   3. Check RPyC server logs: journalctl -u mt5-rpyc -n 50"
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
    account = mt5.account_info()
    if account:
        print(f"   ✅ Account: {account.login}")
        print(f"   ✅ Server: {account.server}")
        print(f"   ✅ Balance: {account.balance}")
        print(f"   ✅ Equity: {account.equity}")
        print(f"   ✅ Margin: {account.margin}")
        print(f"   ✅ Free Margin: {account.margin_free}")
except Exception as e:
    print(f"   ⚠️  Error: {e}")
PYEOF

echo ""
echo "🚀 Next: Run ./TEST_AND_SETUP.sh to complete setup"
echo ""

