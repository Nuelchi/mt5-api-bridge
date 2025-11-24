#!/bin/bash
# Comprehensive diagnosis and fix for MT5 connection issues

set -e

echo "🔍 Comprehensive MT5 Diagnosis and Fix"
echo "======================================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Step 1: Check RPyC server
echo "[1/6] Checking RPyC Server..."
echo "=============================="
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server is running"
    systemctl status mt5-rpyc --no-pager -l | head -10
else
    echo "❌ RPyC server is NOT running"
    echo "   Starting RPyC server..."
    systemctl start mt5-rpyc
    sleep 5
    if systemctl is-active --quiet mt5-rpyc; then
        echo "✅ RPyC server started"
    else
        echo "❌ Failed to start RPyC server"
        echo "   Checking logs:"
        journalctl -u mt5-rpyc -n 20 --no-pager
        exit 1
    fi
fi
echo ""

# Step 2: Check MT5 Terminal process
echo "[2/6] Checking MT5 Terminal Process..."
echo "======================================"
MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "✅ MT5 Terminal process found: PID $MT5_PID"
    ps aux | grep $MT5_PID | grep -v grep
    echo ""
    echo "   Process started:"
    ps -p $MT5_PID -o lstart=
    echo ""
    echo "   Process uptime:"
    ps -p $MT5_PID -o etime=
else
    echo "⚠️  No MT5 Terminal process found"
    echo "   Starting MT5 Terminal..."
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    if [ -f "$MT5_EXE" ]; then
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        sleep 15
        MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
        if [ -n "$MT5_PID" ]; then
            echo "✅ MT5 Terminal started: PID $MT5_PID"
        else
            echo "❌ Failed to start MT5 Terminal"
        fi
    else
        echo "❌ MT5 Terminal executable not found: $MT5_EXE"
    fi
fi
echo ""

# Step 3: Test RPyC connection
echo "[3/6] Testing RPyC Connection..."
echo "==============================="
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    print("   Connecting to RPyC server...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected to RPyC server")
    
    print("   Getting terminal info...")
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ Terminal info retrieved:")
        print(f"      Build: {terminal_info.build}")
        print(f"      Name: {terminal_info.name}")
        print(f"      Company: {terminal_info.company}")
        print(f"      Path: {terminal_info.path}")
        print(f"      Data Path: {terminal_info.data_path}")
        print(f"      Common Path: {terminal_info.common_path}")
    else:
        print("   ⚠️  terminal_info() returned None")
        print("   This means MT5 Terminal is running but not fully initialized")
        sys.exit(1)
        
except Exception as e:
    print(f"   ❌ Connection failed: {e}")
    sys.exit(1)
PYEOF

CONNECTION_OK=$?
echo ""

if [ $CONNECTION_OK -ne 0 ]; then
    echo "⚠️  RPyC connection issue detected"
    echo "   This might mean MT5 Terminal needs more time to initialize"
    echo "   Or the RPyC server needs to be restarted"
    echo ""
fi

# Step 4: Check if MT5 is logged in
echo "[4/6] Checking MT5 Login Status..."
echo "=================================="
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    account = mt5.account_info()
    if account:
        print(f"   ✅ MT5 is logged in!")
        print(f"      Account: {account.login}")
        print(f"      Server: {account.server}")
        print(f"      Balance: {account.balance}")
        print(f"      Equity: {account.equity}")
        sys.exit(0)
    else:
        print("   ⚠️  MT5 Terminal is running but NOT logged in")
        print("   We need to log in...")
        sys.exit(1)
        
except Exception as e:
    print(f"   ⚠️  Error checking login: {e}")
    sys.exit(1)
PYEOF

LOGIN_OK=$?
echo ""

# Step 5: Login if needed
if [ $LOGIN_OK -ne 0 ]; then
    echo "[5/6] Logging in to MT5..."
    echo "=========================="
    echo "   Attempting login..."
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
    
    # First, try to initialize
    print("   Initializing MT5...")
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False: {error}")
        print("   Continuing anyway...")
    
    time.sleep(2)
    
    # Try to login
    print("   Logging in...")
    authorized = mt5.login(5042856355, password="V!QzRxQ7", server="MetaQuotes-Demo")
    
    if authorized:
        time.sleep(3)
        account = mt5.account_info()
        if account:
            print(f"   ✅ Login successful!")
            print(f"      Account: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
            sys.exit(0)
        else:
            print("   ⏳ Login authorized, waiting for account info...")
            time.sleep(5)
            account = mt5.account_info()
            if account:
                print(f"   ✅ Account info retrieved!")
                print(f"      Account: {account.login}")
                print(f"      Server: {account.server}")
                sys.exit(0)
            else:
                print("   ⏳ Still waiting for account info...")
                sys.exit(2)  # Retry
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Login failed: {error}")
        sys.exit(2)  # Retry
        
except TimeoutError:
    print("   ⏳ Timeout - MT5 may still be initializing...")
    sys.exit(2)  # Retry
except Exception as e:
    print(f"   ⏳ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(2)  # Retry
PYEOF

        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            SUCCESS=true
            break
        elif [ $EXIT_CODE -eq 2 ]; then
            echo "   ⏳ Waiting 5 seconds before retry..."
            sleep 5
            continue
        else
            echo "   ⚠️  Unexpected error, retrying..."
            sleep 5
            continue
        fi
    done
    
    echo ""
    
    if [ "$SUCCESS" = true ]; then
        echo "✅ Login successful!"
    else
        echo "❌ Failed to login after $MAX_ATTEMPTS attempts"
        echo ""
        echo "💡 Troubleshooting steps:"
        echo "   1. Check if MT5 Terminal is fully loaded: ps aux | grep terminal64"
        echo "   2. Check RPyC server logs: journalctl -u mt5-rpyc -n 50"
        echo "   3. Try restarting RPyC server: systemctl restart mt5-rpyc"
        echo "   4. Check if MT5 Terminal needs manual login via GUI (may need VNC)"
        exit 1
    fi
else
    echo "[5/6] Skipping login (already logged in)"
fi

echo ""

# Step 6: Final verification
echo "[6/6] Final Verification..."
echo "==========================="
python3 <<PYEOF
from mt5linux import MetaTrader5

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    account = mt5.account_info()
    if account:
        print(f"✅ SUCCESS! MT5 is fully operational!")
        print(f"")
        print(f"   Account Information:")
        print(f"   --------------------")
        print(f"   Login: {account.login}")
        print(f"   Server: {account.server}")
        print(f"   Balance: {account.balance}")
        print(f"   Equity: {account.equity}")
        print(f"   Margin: {account.margin}")
        print(f"   Free Margin: {account.margin_free}")
        print(f"   Leverage: 1:{account.leverage}")
        print(f"   Currency: {account.currency}")
        print(f"   Company: {account.company}")
        print(f"")
        print(f"   ✅ All systems operational!")
    else:
        print("⚠️  Connected but account_info() returned None")
except Exception as e:
    print(f"❌ Verification failed: {e}")
    import traceback
    traceback.print_exc()
PYEOF

echo ""
echo "✅ Diagnosis and fix complete!"
echo ""
echo "📋 Summary:"
echo "   - RPyC Server: $(systemctl is-active mt5-rpyc 2>/dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   - MT5 Terminal: $([ -n "$MT5_PID" ] && echo "✅ Running (PID $MT5_PID)" || echo '❌ Not running')"
echo "   - Login Status: ✅ Logged in"
echo ""
echo "🚀 Next steps:"
echo "   1. Run: ./TEST_AND_SETUP.sh"
echo "      This will start the API service, configure Nginx, and set up SSL"
echo ""
