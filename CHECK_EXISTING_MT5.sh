#!/bin/bash
# Check for existing MT5 processes and try to use them

echo "🔍 Checking for Existing MT5 Processes"
echo "======================================"
echo ""

# Check all processes
echo "[1/4] Checking all processes..."
ALL_PROCS=$(ps aux | grep -E "terminal|mt5|MetaTrader|wine.*terminal" | grep -v grep)
if [ -n "$ALL_PROCS" ]; then
    echo "✅ Found processes:"
    echo "$ALL_PROCS"
else
    echo "❌ No MT5-related processes found"
fi
echo ""

# Check for any Wine processes
echo "[2/4] Checking Wine processes..."
WINE_PROCS=$(ps aux | grep -E "wine.*\.exe" | grep -v grep)
if [ -n "$WINE_PROCS" ]; then
    echo "✅ Found Wine processes:"
    echo "$WINE_PROCS"
else
    echo "❌ No Wine processes found"
fi
echo ""

# Check if RPyC can connect to anything
echo "[3/4] Testing RPyC connection..."
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys

try:
    print("   🔌 Attempting to connect to MT5 via RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Try to get terminal info
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ MT5 Terminal is accessible via RPyC!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        
        # Try account info
        account = mt5.account_info()
        if account:
            print(f"      ✅ Account logged in: {account.login} @ {account.server}")
        else:
            print(f"      ⚠️  Not logged in")
        sys.exit(0)
    else:
        print("   ⚠️  RPyC connected but terminal_info() is None")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    sys.exit(1)
PYEOF

RPYC_RESULT=$?
echo ""

# Check systemd services
echo "[4/4] Checking systemd services..."
if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
    echo "✅ RPyC service is running"
    systemctl status mt5-rpyc --no-pager -l | head -5
else
    echo "❌ RPyC service is not running"
fi

if systemctl is-active --quiet mt5-api; then
    echo "✅ MT5 API service is running"
else
    echo "❌ MT5 API service is not running"
fi
echo ""

# Summary
echo "==========================="
if [ $RPYC_RESULT -eq 0 ]; then
    echo "✅ MT5 is accessible via RPyC!"
    echo ""
    echo "📋 Even though MT5 Terminal process may not be visible,"
    echo "   RPyC can connect to it. This means:"
    echo "   1. MT5 Terminal is running (possibly in a different way)"
    echo "   2. RPyC server is working"
    echo "   3. The API should work!"
    echo ""
    echo "   Test the API:"
    echo "   curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' \\"
    echo "     -H 'Authorization: Bearer YOUR_TOKEN'"
else
    echo "❌ MT5 is not accessible"
    echo ""
    echo "📋 The issue is that MT5 Terminal crashes immediately when started."
    echo "   This is a Wine compatibility issue."
    echo ""
    echo "📋 Possible solutions:"
    echo "   1. Check if MT5 was working before and use that process"
    echo "   2. Try installing Wine components:"
    echo "      apt-get install winetricks"
    echo "      winetricks vcrun2015 vcrun2019 corefonts"
    echo "   3. Check if there's a different Wine prefix with working MT5"
    echo "   4. Consider using MetaAPI instead (cloud-based, no Wine needed)"
fi
echo ""

