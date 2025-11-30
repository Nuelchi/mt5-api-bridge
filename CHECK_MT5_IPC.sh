#!/bin/bash
# Check MT5 Terminal IPC connection status

echo "🔍 Checking MT5 Terminal IPC Connection"
echo "========================================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "[1/3] Checking MT5 Terminal process..."
echo "======================================"
MT5_PIDS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep | awk '{print $2}')
if [ -n "$MT5_PIDS" ]; then
    echo "✅ MT5 Terminal is running"
    for pid in $MT5_PIDS; do
        ps -p $pid -o pid=,etime=,cmd= | head -1
    done
else
    echo "❌ MT5 Terminal is NOT running"
    exit 1
fi
echo ""

echo "[2/3] Testing RPyC connection..."
echo "================================="
python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   Connecting to RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection established")
    
    # Try multiple approaches
    print("   Testing is_initialized()...")
    try:
        is_init = mt5.is_initialized()
        print(f"   is_initialized() = {is_init}")
    except Exception as e:
        print(f"   ⚠️  is_initialized() error: {e}")
    
    print("   Testing initialize()...")
    try:
        initialized = mt5.initialize()
        print(f"   initialize() = {initialized}")
        if initialized:
            time.sleep(2)
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal info: Build {terminal_info.build}")
                print("   ✅ MT5 Terminal is ready!")
                sys.exit(0)
            else:
                print("   ⚠️  terminal_info() is None")
    except Exception as e:
        error_str = str(e).lower()
        if "timeout" in error_str or "expired" in error_str:
            print(f"   ⏳ Timeout: {e}")
        elif "ipc" in error_str or "10004" in str(e):
            print(f"   ❌ IPC Error: {e}")
            print("   This means MT5 Terminal is not ready for API calls")
        else:
            print(f"   ❌ Error: {e}")
    
    # Try login directly (sometimes this works even if initialize fails)
    print("   Testing direct login attempt...")
    print("   (This will fail but shows if MT5 Terminal responds at all)")
    try:
        # Use a test login that will fail but shows if MT5 responds
        result = mt5.login(999999, password="test", server="Test")
        print(f"   Login attempt returned: {result}")
    except Exception as e:
        error_str = str(e).lower()
        if "timeout" in error_str or "expired" in error_str:
            print(f"   ⏳ Login timeout: {e}")
            print("   MT5 Terminal is not responding to any calls")
        elif "ipc" in error_str or "10004" in str(e):
            print(f"   ❌ IPC Error on login: {e}")
            print("   MT5 Terminal needs to be fully initialized first")
        else:
            print(f"   Login error (expected): {e}")
            print("   But MT5 Terminal responded - this is good!")
    
    sys.exit(1)
    
except Exception as e:
    print(f"   ❌ Connection error: {e}")
    sys.exit(1)
PYEOF

EXIT_CODE=$?
echo ""

echo "[3/3] Recommendations..."
echo "======================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ MT5 Terminal is ready!"
    echo ""
    echo "📋 You can now connect your account via API"
else
    echo "❌ MT5 Terminal is not ready for API calls"
    echo ""
    echo "💡 The 'No IPC connection' error means MT5 Terminal needs to be:"
    echo "   1. Fully started (process running) ✅"
    echo "   2. Fully initialized (accepting API calls) ❌"
    echo "   3. Optionally logged in (for some operations)"
    echo ""
    echo "🔧 Solutions:"
    echo "   1. Wait longer - MT5 Terminal can take 5-10 minutes to fully initialize"
    echo "   2. Restart MT5 Terminal: sudo ./FIX_MT5_CRASH.sh"
    echo "   3. Check MT5 screen log: tail -100 /tmp/mt5_screen.log"
    echo "   4. Try logging in manually via VNC first (if VNC is working)"
    echo "   5. Check if MT5 Terminal is stuck: screen -r mt5_terminal"
fi
echo ""
