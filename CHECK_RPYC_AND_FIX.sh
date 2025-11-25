#!/bin/bash
# Check RPyC server logs and fix MT5 Terminal connection issues

set -e

echo "🔍 Checking RPyC Server and MT5 Terminal Connection"
echo "====================================================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Step 1: Check RPyC server logs
echo "[1/4] Checking RPyC Server Logs..."
echo "=================================="
echo "Recent RPyC server logs:"
journalctl -u mt5-rpyc -n 30 --no-pager | tail -20
echo ""

# Step 2: Check MT5 Terminal process
echo "[2/4] Checking MT5 Terminal Process..."
echo "======================================"
MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "✅ MT5 Terminal process found: PID $MT5_PID"
    ps aux | grep $MT5_PID | grep -v grep
    echo ""
    echo "   Process uptime:"
    ps -p $MT5_PID -o etime=
    echo ""
    echo "   ⚠️  The process has been running for a while but MT5 isn't responding"
    echo "   This might mean MT5 Terminal needs to be restarted"
    echo ""
    read -p "   Restart MT5 Terminal? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   Stopping MT5 Terminal..."
        kill $MT5_PID || pkill -f "terminal64.exe" || true
        sleep 5
        MT5_PID=""
    fi
else
    echo "⚠️  No MT5 Terminal process found"
fi
echo ""

# Step 3: Start/restart MT5 Terminal if needed
if [ -z "$MT5_PID" ]; then
    echo "[3/4] Starting MT5 Terminal..."
    echo "=============================="
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    
    if [ -f "$MT5_EXE" ]; then
        echo "   Starting MT5 Terminal..."
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        sleep 20
        echo "   ✅ MT5 Terminal started"
        echo "   ⏳ Waiting 30 seconds for MT5 Terminal to fully initialize..."
        sleep 30
    else
        echo "   ❌ MT5 Terminal executable not found: $MT5_EXE"
        exit 1
    fi
else
    echo "[3/4] MT5 Terminal is running (skipping restart)"
fi
echo ""

# Step 4: Test connection with longer timeout
echo "[4/4] Testing MT5 Connection (with longer wait)..."
echo "================================================="
echo "   Waiting 10 more seconds for MT5 to be ready..."
sleep 10

python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   Connecting to RPyC server...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected to RPyC server")
    
    print("   Waiting 5 seconds before trying to initialize...")
    time.sleep(5)
    
    print("   Initializing MT5 (this may take 10-20 seconds)...")
    # Try with a longer timeout by setting it in the RPyC connection
    # Unfortunately mt5linux doesn't expose timeout, so we'll just try
    try:
        if mt5.initialize():
            print("   ✅ MT5 initialized successfully!")
        else:
            error = mt5.last_error()
            print(f"   ⚠️  Initialize returned False: {error}")
            print("   But continuing anyway...")
    except TimeoutError as e:
        print(f"   ❌ Timeout: {e}")
        print("   This means MT5 Terminal is not responding to the Windows Python")
        print("   The MT5 Terminal process might be running but not fully initialized")
        sys.exit(1)
    
    time.sleep(3)
    
    print("   Trying to login...")
    authorized = mt5.login(5042856355, password="V!QzRxQ7", server="MetaQuotes-Demo")
    
    if authorized:
        print("   ✅ Login authorized")
        time.sleep(5)
        
        account = mt5.account_info()
        if account:
            print(f"   ✅ SUCCESS!")
            print(f"      Account: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
            sys.exit(0)
        else:
            print("   ⏳ Login authorized but account_info() is None")
            print("   Waiting 10 more seconds...")
            time.sleep(10)
            account = mt5.account_info()
            if account:
                print(f"   ✅ Account info retrieved!")
                print(f"      Account: {account.login}")
                sys.exit(0)
            else:
                print("   ⚠️  Still no account info")
                sys.exit(1)
    else:
        error = mt5.last_error()
        print(f"   ❌ Login failed: {error}")
        sys.exit(1)
        
except TimeoutError as e:
    print(f"   ❌ Timeout error: {e}")
    print("")
    print("   💡 This means the RPyC call is timing out.")
    print("   Possible causes:")
    print("   1. MT5 Terminal is not fully initialized yet")
    print("   2. Windows Python in Wine can't connect to MT5 Terminal")
    print("   3. MT5 Terminal needs to be logged in via GUI first")
    print("")
    print("   Try:")
    print("   - Wait longer (MT5 Terminal can take 60+ seconds to fully initialize)")
    print("   - Check RPyC server logs: journalctl -u mt5-rpyc -f")
    print("   - Restart MT5 Terminal and wait longer")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

EXIT_CODE=$?

echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ SUCCESS! MT5 is working!"
    echo ""
    echo "📋 Final Status:"
    python3 <<PYEOF
from mt5linux import MetaTrader5
mt5 = MetaTrader5(host='localhost', port=8001)
account = mt5.account_info()
if account:
    print(f"   ✅ Account: {account.login}")
    print(f"   ✅ Server: {account.server}")
    print(f"   ✅ Balance: {account.balance}")
    print(f"   ✅ Equity: {account.equity}")
PYEOF
    echo ""
    echo "🚀 Next: Run ./TEST_AND_SETUP.sh to complete setup"
else
    echo "❌ Failed to connect to MT5"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Check RPyC server logs: journalctl -u mt5-rpyc -n 50"
    echo "   2. Try waiting longer (MT5 Terminal can take 60+ seconds)"
    echo "   3. Check if MT5 Terminal needs manual login via GUI"
    echo "   4. Try restarting RPyC server: systemctl restart mt5-rpyc"
fi

echo ""

