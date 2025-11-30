#!/bin/bash
# Diagnose RPyC timeout issues

echo "🔍 Diagnosing RPyC Timeout Issues"
echo "=================================="
echo ""

# Step 1: Check RPyC server status
echo "[1/4] Checking RPyC server status..."
echo "===================================="
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server is running"
    systemctl status mt5-rpyc --no-pager -l | head -10
else
    echo "❌ RPyC server is NOT running"
    echo "   Starting RPyC server..."
    sudo systemctl start mt5-rpyc
    sleep 3
    if systemctl is-active --quiet mt5-rpyc; then
        echo "✅ RPyC server started"
    else
        echo "❌ Failed to start RPyC server"
        echo "   Check logs: journalctl -u mt5-rpyc -n 50"
    fi
fi
echo ""

# Step 2: Check MT5 Terminal process
echo "[2/4] Checking MT5 Terminal process..."
echo "======================================"
MT5_PIDS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep | awk '{print $2}')
if [ -n "$MT5_PIDS" ]; then
    echo "✅ MT5 Terminal is running (PIDs: $MT5_PIDS)"
    for pid in $MT5_PIDS; do
        ps -p $pid -o pid=,etime=,cmd= | head -1
    done
else
    echo "❌ MT5 Terminal is NOT running"
    echo "   Run: sudo ./ENSURE_MT5_RUNNING.sh"
fi
echo ""

# Step 3: Test RPyC connection with timeout
echo "[3/4] Testing RPyC connection..."
echo "================================"
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

print("   Connecting to RPyC (localhost:8001)...")
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection object created")
    
    print("   Testing terminal_info() with 5s timeout...")
    start_time = time.time()
    try:
        terminal_info = mt5.terminal_info()
        elapsed = time.time() - start_time
        if terminal_info:
            print(f"   ✅ terminal_info() succeeded in {elapsed:.2f}s")
            print(f"      Build: {terminal_info.build}")
            sys.exit(0)
        else:
            print(f"   ⚠️  terminal_info() returned None (took {elapsed:.2f}s)")
            print("   MT5 Terminal may not be fully initialized")
            sys.exit(1)
    except Exception as e:
        elapsed = time.time() - start_time
        error_str = str(e).lower()
        if "timeout" in error_str or "expired" in error_str:
            print(f"   ❌ Timeout after {elapsed:.2f}s: {e}")
            print("   RPyC is not responding - MT5 Terminal may be frozen")
        else:
            print(f"   ❌ Error: {e}")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Connection error: {e}")
    sys.exit(1)
PYEOF

CONN_TEST=$?
echo ""

# Step 4: Check for port conflicts
echo "[4/4] Checking for port conflicts..."
echo "===================================="
PORT_8001=$(sudo lsof -i:8001 2>/dev/null | grep -v COMMAND || echo "")
if [ -n "$PORT_8001" ]; then
    echo "   Processes using port 8001:"
    echo "$PORT_8001"
else
    echo "   ✅ No processes found on port 8001"
fi
echo ""

# Summary
echo "=================================="
if [ $CONN_TEST -eq 0 ]; then
    echo "✅ RPyC connection is working!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
else
    echo "❌ RPyC connection is NOT working"
    echo ""
    echo "💡 Troubleshooting steps:"
    echo "   1. Restart RPyC server: sudo systemctl restart mt5-rpyc"
    echo "   2. Restart MT5 Terminal: sudo ./ENSURE_MT5_RUNNING.sh"
    echo "   3. Check RPyC logs: journalctl -u mt5-rpyc -n 50 --no-pager"
    echo "   4. Check MT5 screen log: tail -50 /tmp/mt5_screen.log"
    echo ""
    echo "   If RPyC keeps timing out, MT5 Terminal may need to be restarted."
fi
echo ""

