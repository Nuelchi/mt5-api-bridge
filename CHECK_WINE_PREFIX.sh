#!/bin/bash
# Check Wine prefix alignment between RPyC and MT5 Terminal

echo "🔍 Checking Wine Prefix Configuration"
echo "====================================="
echo ""

# Step 1: Check current Wine prefix
echo "[1/4] Checking Wine prefix environment..."
echo "   WINEPREFIX: ${WINEPREFIX:-not set (using default ~/.wine)}"
if [ -n "$WINEPREFIX" ]; then
    echo "   ✅ WINEPREFIX is set to: $WINEPREFIX"
else
    DEFAULT_WINE="$HOME/.wine"
    echo "   Using default: $DEFAULT_WINE"
fi
echo ""

# Step 2: Check MT5 Terminal processes and their Wine prefix
echo "[2/4] Checking MT5 Terminal processes..."
MT5_PROCS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep)
if [ -n "$MT5_PROCS" ]; then
    echo "✅ Found MT5 Terminal processes:"
    echo "$MT5_PROCS"
    echo ""
    
    # Try to determine Wine prefix from process
    MT5_PID=$(echo "$MT5_PROCS" | head -1 | awk '{print $2}')
    echo "   Checking Wine prefix for PID $MT5_PID..."
    
    # Check environment variables
    if [ -f "/proc/$MT5_PID/environ" ]; then
        MT5_WINEPREFIX=$(cat /proc/$MT5_PID/environ 2>/dev/null | tr '\0' '\n' | grep WINEPREFIX | cut -d= -f2)
        if [ -n "$MT5_WINEPREFIX" ]; then
            echo "   MT5 Terminal WINEPREFIX: $MT5_WINEPREFIX"
        else
            echo "   MT5 Terminal WINEPREFIX: not set (using default)"
        fi
    fi
else
    echo "❌ No MT5 Terminal processes found"
fi
echo ""

# Step 3: Check RPyC service configuration
echo "[3/4] Checking RPyC service configuration..."
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC service is running"
    RPYC_PID=$(systemctl show -p MainPID --value mt5-rpyc)
    echo "   RPyC PID: $RPYC_PID"
    
    # Check RPyC service file
    if [ -f /etc/systemd/system/mt5-rpyc.service ]; then
        echo "   RPyC service file:"
        grep -E "WINEPREFIX|Environment" /etc/systemd/system/mt5-rpyc.service || echo "   No WINEPREFIX in service file"
    fi
else
    echo "❌ RPyC service is not running"
fi
echo ""

# Step 4: Test with explicit Wine prefix
echo "[4/4] Testing RPyC connection with explicit wait..."
cd /opt/mt5-api-bridge
source venv/bin/activate

# Wait longer and try multiple times
echo "   Waiting 60 seconds for MT5 to fully initialize..."
sleep 60

echo ""
echo "🧪 Testing RPyC Connection (Attempt 1)..."
python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   🔌 Connecting to MT5 via RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection established")
    
    print("   ⏳ Waiting 10 seconds...")
    time.sleep(10)
    
    print("   📊 Getting terminal info...")
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ MT5 Terminal is accessible!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        
        account = mt5.account_info()
        if account:
            print(f"      ✅ Account: {account.login} @ {account.server}")
        else:
            print(f"      ⚠️  Not logged in")
        sys.exit(0)
    else:
        print("   ❌ terminal_info() still returns None")
        sys.exit(1)
        
except Exception as e:
    print(f"   ❌ Error: {e}")
    sys.exit(1)
PYEOF

TEST_RESULT=$?

if [ $TEST_RESULT -ne 0 ]; then
    echo ""
    echo "   ⏳ Waiting another 30 seconds and trying again..."
    sleep 30
    
    echo ""
    echo "🧪 Testing RPyC Connection (Attempt 2)..."
    python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    time.sleep(5)
    
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ MT5 Terminal is accessible!")
        print(f"      Version: {terminal_info.build}")
        sys.exit(0)
    else:
        print("   ❌ Still not accessible")
        sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    sys.exit(1)
PYEOF
    TEST_RESULT=$?
fi

echo ""
echo "==========================="
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ MT5 Terminal is now accessible via RPyC!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   2. If not logged in, log in via API"
else
    echo "❌ MT5 Terminal still not accessible after 90+ seconds"
    echo ""
    echo "📋 This suggests a deeper issue:"
    echo "   1. RPyC server might be connecting to wrong Wine environment"
    echo "   2. MT5 Terminal might need to be started differently"
    echo "   3. There might be a Wine prefix mismatch"
    echo ""
    echo "📋 Check:"
    echo "   1. MT5 screen log: tail -100 /tmp/mt5_screen.log"
    echo "   2. RPyC logs: journalctl -u mt5-rpyc -f"
    echo "   3. MT5 processes: ps aux | grep terminal"
fi
echo ""

