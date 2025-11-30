#!/bin/bash
# Diagnose why RPyC can't access MT5 Terminal

echo "🔍 Diagnosing RPyC-MT5 Connection"
echo "=================================="
echo ""

# Step 1: Check MT5 Terminal processes
echo "[1/5] Checking MT5 Terminal processes..."
MT5_PROCS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep)
if [ -n "$MT5_PROCS" ]; then
    echo "✅ Found MT5 Terminal processes:"
    echo "$MT5_PROCS"
    echo ""
    
    # Get PIDs
    MT5_PIDS=$(echo "$MT5_PROCS" | awk '{print $2}')
    for pid in $MT5_PIDS; do
        echo "   Process $pid details:"
        ps -p $pid -o user=,pid=,lstart=,etime=,cmd= | head -1
        echo "   Wine prefix: $(pwdx $pid 2>/dev/null || echo 'unknown')"
    done
else
    echo "❌ No MT5 Terminal processes found"
fi
echo ""

# Step 2: Check RPyC server
echo "[2/5] Checking RPyC server..."
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC service is running"
    RPYC_PID=$(systemctl show -p MainPID --value mt5-rpyc)
    echo "   PID: $RPYC_PID"
    ps -p $RPYC_PID -o lstart=,cmd= | head -1
else
    echo "❌ RPyC service is not running"
fi

# Check port 8001
if ss -tlnp | grep -q ":8001"; then
    echo "✅ Port 8001 is in use:"
    ss -tlnp | grep ":8001"
else
    echo "❌ Port 8001 is not in use"
fi
echo ""

# Step 3: Test RPyC connection with detailed output
echo "[3/5] Testing RPyC connection with detailed diagnostics..."
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   🔌 Connecting to MT5 via RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection established")
    
    print("   ⏳ Waiting 5 seconds...")
    time.sleep(5)
    
    print("   📊 Getting terminal info...")
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ Terminal info retrieved!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        print(f"      Path: {terminal_info.path}")
        print(f"      Data Path: {terminal_info.data_path}")
        print(f"      Common Path: {terminal_info.common_path}")
    else:
        print("   ❌ terminal_info() returned None")
        print("   This means MT5 Terminal is not accessible via RPyC")
        print("   Possible reasons:")
        print("     1. MT5 Terminal is not initialized")
        print("     2. RPyC is connected to wrong MT5 instance")
        print("     3. MT5 Terminal needs to be restarted")
        sys.exit(1)
    
    print("   📊 Getting account info...")
    account = mt5.account_info()
    if account:
        print(f"   ✅ Account info retrieved!")
        print(f"      Login: {account.login}")
        print(f"      Server: {account.server}")
        print(f"      Balance: {account.balance}")
        print(f"      Equity: {account.equity}")
    else:
        print("   ⚠️  account_info() returned None (not logged in)")
    
    sys.exit(0)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

TEST_RESULT=$?
echo ""

# Step 4: Check Wine processes
echo "[4/5] Checking Wine processes..."
WINE_PROCS=$(ps aux | grep -E "wine.*terminal|wineserver" | grep -v grep)
if [ -n "$WINE_PROCS" ]; then
    echo "✅ Found Wine processes:"
    echo "$WINE_PROCS"
else
    echo "⚠️  No Wine processes found (this might be normal)"
fi
echo ""

# Step 5: Recommendations
echo "[5/5] Recommendations"
echo "===================="
echo ""

if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ MT5 Terminal is accessible via RPyC!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   2. If account is not logged in, log in via API or MT5 terminal"
else
    echo "❌ MT5 Terminal is not accessible via RPyC"
    echo ""
    echo "📋 Possible Solutions:"
    echo ""
    echo "Option 1: Restart MT5 Terminal (if it's not the right instance)"
    echo "   ./FIX_MT5_CRASH.sh"
    echo ""
    echo "Option 2: Check if MT5 Terminal needs to be logged in"
    echo "   The MT5 Terminal process exists but may not be initialized"
    echo ""
    echo "Option 3: Wait longer for MT5 to initialize"
    echo "   MT5 Terminal can take 30-60 seconds to fully initialize"
    echo "   Try: sleep 30 && ./VERIFY_MT5_CONNECTION.sh"
    echo ""
    echo "Option 4: Check RPyC configuration"
    echo "   RPyC might be connecting to a different Wine prefix"
    echo "   Check: journalctl -u mt5-rpyc -n 50"
fi
echo ""

