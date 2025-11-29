#!/bin/bash
# Comprehensive diagnostic script for MT5 connection issues

echo "🔍 MT5 Connection Diagnostic"
echo "============================"
echo ""

# 1. Check if MT5 Terminal process is running
echo "[1/6] Checking MT5 Terminal Process..."
echo "======================================"
MT5_PID=$(pgrep -f "terminal64.exe\|terminal.exe" | head -1)
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
    echo "❌ No MT5 Terminal process found"
    echo "   The terminal is NOT running!"
fi
echo ""

# 2. Check RPyC server status
echo "[2/6] Checking RPyC Server..."
echo "============================="
if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
    echo "✅ RPyC service is running"
    systemctl status mt5-rpyc --no-pager -l | head -15
else
    echo "❌ RPyC service is NOT running"
    echo "   Checking if port 8001 is in use..."
    if ss -tlnp | grep -q ":8001"; then
        echo "   ⚠️  Port 8001 is in use but service not active"
        ss -tlnp | grep ":8001"
    else
        echo "   ❌ Port 8001 is not listening"
    fi
fi
echo ""

# 3. Test RPyC connection
echo "[3/6] Testing RPyC Connection..."
echo "==============================="
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys

try:
    print("   Connecting to RPyC server on localhost:8001...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection successful")
    
    print("   Attempting to initialize MT5...")
    if mt5.initialize():
        print("   ✅ MT5 initialize() succeeded")
        
        # Try to get terminal info
        try:
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal info retrieved: {terminal_info.name}")
            else:
                print("   ⚠️  Terminal info returned None")
        except Exception as e:
            print(f"   ⚠️  Could not get terminal info: {e}")
        
        # Try to get account info
        try:
            account_info = mt5.account_info()
            if account_info:
                print(f"   ✅ Account info retrieved: Login {account_info.login}")
            else:
                print("   ⚠️  Account info returned None (not logged in)")
        except Exception as e:
            print(f"   ⚠️  Could not get account info: {e}")
    else:
        error = mt5.last_error() if hasattr(mt5, 'last_error') else "Unknown"
        print(f"   ❌ MT5 initialize() failed: {error}")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running or not accessible")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

RPYC_TEST=$?
echo ""

# 4. Check Wine/Xvfb
echo "[4/6] Checking Wine/Xvfb..."
echo "==========================="
if pgrep -x Xvfb > /dev/null; then
    echo "✅ Xvfb (virtual display) is running"
    ps aux | grep Xvfb | grep -v grep
else
    echo "❌ Xvfb is NOT running"
    echo "   MT5 Terminal needs virtual display to run"
fi

if command -v wine > /dev/null; then
    echo "✅ Wine is installed"
    wine --version
else
    echo "❌ Wine is NOT installed"
fi
echo ""

# 5. Check MT5 API Bridge service
echo "[5/6] Checking MT5 API Bridge Service..."
echo "========================================"
if systemctl is-active --quiet mt5-api; then
    echo "✅ MT5 API Bridge service is running"
    systemctl status mt5-api --no-pager -l | head -10
else
    echo "❌ MT5 API Bridge service is NOT running"
fi
echo ""

# 6. Check recent errors
echo "[6/6] Recent Errors from MT5 API Bridge..."
echo "==========================================="
journalctl -u mt5-api -n 20 --no-pager | grep -i "error\|timeout\|failed\|expired" | tail -10
echo ""

# Summary
echo "📊 Summary"
echo "=========="
if [ -n "$MT5_PID" ] && [ $RPYC_TEST -eq 0 ]; then
    echo "✅ MT5 Terminal is running"
    echo "✅ RPyC connection works"
    echo ""
    echo "💡 If you're still getting errors, the terminal may not be logged in."
    echo "   Try logging in manually or check account credentials."
elif [ -n "$MT5_PID" ] && [ $RPYC_TEST -ne 0 ]; then
    echo "⚠️  MT5 Terminal is running BUT RPyC connection is broken"
    echo ""
    echo "💡 Try restarting RPyC server:"
    echo "   sudo systemctl restart mt5-rpyc"
elif [ -z "$MT5_PID" ] && [ $RPYC_TEST -eq 0 ]; then
    echo "⚠️  RPyC server is running BUT MT5 Terminal is NOT running"
    echo ""
    echo "💡 Start MT5 Terminal:"
    echo "   export DISPLAY=:99"
    echo "   export WINEPREFIX=\$HOME/.wine"
    echo "   wine \"\$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe\" &"
else
    echo "❌ Both MT5 Terminal and RPyC connection are NOT working"
    echo ""
    echo "💡 You need to:"
    echo "   1. Start MT5 Terminal"
    echo "   2. Start RPyC server"
    echo "   3. Ensure terminal is logged in"
fi
echo ""

