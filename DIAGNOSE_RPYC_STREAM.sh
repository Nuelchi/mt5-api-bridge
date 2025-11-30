#!/bin/bash
# Diagnose RPyC stream closure issues

echo "🔍 Diagnosing RPyC Stream Closure"
echo "=================================="
echo ""

# Check RPyC logs
echo "[1/3] Checking RPyC server logs..."
echo "==================================="
journalctl -u mt5-rpyc -n 100 --no-pager | tail -50
echo ""

# Check if RPyC server is stable
echo "[2/3] Checking RPyC server status..."
echo "===================================="
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server is running"
    systemctl status mt5-rpyc --no-pager -l | head -15
else
    echo "❌ RPyC server is NOT running"
    echo "   Starting RPyC server..."
    sudo systemctl start mt5-rpyc
    sleep 3
fi
echo ""

# Test RPyC connection stability
echo "[3/3] Testing RPyC connection stability..."
echo "==========================================="
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

print("   Creating RPyC connection...")
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connection object created")
    
    # Try a simple operation first
    print("   Testing connection with a simple call...")
    try:
        # Try to get version or do something simple
        print("   Attempting initialize() with timeout handling...")
        initialized = mt5.initialize()
        print(f"   initialize() returned: {initialized}")
        
        if initialized:
            print("   ✅ MT5 initialized successfully!")
            time.sleep(1)
            
            # Try terminal_info
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal info: Build {terminal_info.build}")
            else:
                print("   ⚠️  terminal_info() is None")
        else:
            error = mt5.last_error()
            print(f"   ⚠️  Initialize returned False: {error}")
            
    except Exception as e:
        error_str = str(e).lower()
        if "stream" in error_str or "closed" in error_str:
            print(f"   ❌ Stream error: {e}")
            print("   RPyC connection is being closed unexpectedly")
            print("   This suggests RPyC server or MT5 Terminal is unstable")
        elif "timeout" in error_str or "expired" in error_str:
            print(f"   ⏳ Timeout: {e}")
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

EXIT_CODE=$?
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ RPyC connection is stable"
else
    echo "❌ RPyC connection has issues"
    echo ""
    echo "💡 Try:"
    echo "   1. Restart RPyC: sudo systemctl restart mt5-rpyc"
    echo "   2. Restart MT5 Terminal: sudo ./FIX_MT5_CRASH.sh"
    echo "   3. Check if there are multiple RPyC processes: ps aux | grep rpyc"
fi
echo ""
