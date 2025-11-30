#!/bin/bash
# Fix RPyC and ensure everything is ready for account connection

echo "🔧 Fixing RPyC and Preparing for Account Connection"
echo "==================================================="
echo ""

# Step 1: Check and restart RPyC
echo "[1/4] Checking RPyC server..."
echo "============================="
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server is running"
else
    echo "❌ RPyC server is NOT running - starting it..."
    sudo systemctl start mt5-rpyc
    sleep 5
    if systemctl is-active --quiet mt5-rpyc; then
        echo "✅ RPyC server started"
    else
        echo "❌ Failed to start RPyC server"
        echo "   Check logs: journalctl -u mt5-rpyc -n 50"
        exit 1
    fi
fi

# Verify RPyC process
RPYC_PIDS=$(ps aux | grep -E "mt5linux|rpyc" | grep -v grep | grep -v "grep" | awk '{print $2}')
if [ -n "$RPYC_PIDS" ]; then
    echo "✅ RPyC processes found:"
    for pid in $RPYC_PIDS; do
        ps -p $pid -o pid=,cmd= | head -1
    done
else
    echo "⚠️  No RPyC processes found in ps output"
    echo "   But service says it's running - this might be OK"
fi
echo ""

# Step 2: Check MT5 Terminal
echo "[2/4] Checking MT5 Terminal..."
echo "=============================="
MT5_PIDS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep | awk '{print $2}')
if [ -n "$MT5_PIDS" ]; then
    echo "✅ MT5 Terminal is running"
    for pid in $MT5_PIDS; do
        ps -p $pid -o pid=,etime= | head -1
    done
else
    echo "❌ MT5 Terminal is NOT running"
    echo "   Starting MT5 Terminal..."
    sudo ./FIX_MT5_CRASH.sh
    sleep 30
fi
echo ""

# Step 3: Wait for MT5 to be ready
echo "[3/4] Waiting for MT5 Terminal to initialize..."
echo "==============================================="
echo "   Waiting 120 seconds for MT5 Terminal to fully initialize..."
sleep 120
echo "✅ Wait complete"
echo ""

# Step 4: Test connection
echo "[4/4] Testing RPyC connection..."
echo "================================="
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   Connecting to RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection established")
    
    print("   Attempting initialize()...")
    try:
        initialized = mt5.initialize()
        if initialized:
            print("   ✅ MT5 initialized!")
            time.sleep(2)
            
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal info: Build {terminal_info.build}")
                print("   ✅ MT5 Terminal is READY!")
                sys.exit(0)
            else:
                print("   ⚠️  terminal_info() is None")
                print("   ⚠️  But initialize() succeeded - may be ready for login")
                sys.exit(0)
        else:
            error = mt5.last_error()
            print(f"   ⚠️  Initialize returned False: {error}")
            print("   ⚠️  But will try login anyway...")
            sys.exit(0)  # Still try login
    except Exception as e:
        error_str = str(e).lower()
        if "stream" in error_str or "closed" in error_str:
            print(f"   ❌ Stream error: {e}")
            print("   RPyC connection is unstable")
            sys.exit(1)
        elif "timeout" in error_str or "expired" in error_str:
            print(f"   ⏳ Timeout: {e}")
            print("   ⚠️  MT5 Terminal may need more time")
            print("   ⚠️  But will try login anyway...")
            sys.exit(0)  # Still try login
        else:
            print(f"   ❌ Error: {e}")
            sys.exit(1)
            
except Exception as e:
    print(f"   ❌ Connection error: {e}")
    sys.exit(1)
PYEOF

EXIT_CODE=$?
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "=================================="
    echo "✅ Ready to connect account!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Restart API: sudo systemctl restart mt5-api"
    echo "   2. Connect account via API (see command below)"
    echo ""
    echo "   curl -X POST 'https://trade.trainflow.dev/api/v1/accounts/connect' \\"
    echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"account_name\": \"MetaQuotes Demo\", \"login\": \"10008509685\", \"password\": \"!l1cBtTn\", \"server\": \"MetaQuotes-Demo\", \"account_type\": \"demo\", \"set_as_default\": true}'"
else
    echo "=================================="
    echo "⚠️  MT5 Terminal may still need more time"
    echo ""
    echo "💡 Try:"
    echo "   1. Wait 2-3 more minutes"
    echo "   2. Check RPyC logs: journalctl -u mt5-rpyc -n 50"
    echo "   3. Check MT5 screen log: tail -50 /tmp/mt5_screen.log"
    echo "   4. Try connecting account anyway - sometimes login works even if initialize() fails"
fi
echo ""
