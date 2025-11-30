#!/bin/bash
# Full restart of MT5 Terminal and RPyC to fix timeout issues

echo "🔄 Full MT5 Terminal Restart"
echo "============================"
echo ""

# Step 1: Kill all MT5 processes
echo "[1/5] Stopping all MT5 Terminal processes..."
echo "============================================"
pkill -f "terminal64.exe" || true
pkill -f "terminal.exe" || true
sleep 3

# Kill all screen sessions
screen -wipe >/dev/null 2>&1 || true
screen -S mt5_terminal -X quit 2>/dev/null || true
sleep 2

# Verify all processes are stopped
MT5_PIDS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep | awk '{print $2}')
if [ -n "$MT5_PIDS" ]; then
    echo "   Force killing remaining processes..."
    for pid in $MT5_PIDS; do
        kill -9 $pid 2>/dev/null || true
    done
    sleep 2
fi

if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "❌ Some MT5 processes are still running"
else
    echo "✅ All MT5 processes stopped"
fi
echo ""

# Step 2: Restart RPyC server
echo "[2/5] Restarting RPyC server..."
echo "==============================="
sudo systemctl restart mt5-rpyc
sleep 5
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server restarted"
else
    echo "❌ RPyC server failed to start"
    exit 1
fi
echo ""

# Step 3: Ensure virtual display
echo "[3/5] Ensuring virtual display..."
echo "=================================="
if ! pgrep -x Xvfb > /dev/null; then
    echo "   Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
    echo "✅ Virtual display started"
else
    echo "✅ Virtual display already running"
fi
echo ""

# Step 4: Start MT5 Terminal fresh
echo "[4/5] Starting MT5 Terminal..."
echo "=============================="
export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ ! -f "$MT5FILE" ]; then
    echo "❌ MT5 Terminal not found at: $MT5FILE"
    exit 1
fi

# Clean up old screen sessions
screen -wipe >/dev/null 2>&1 || true

# Start MT5 in a fresh screen session
screen -dmS mt5_terminal bash -c "export DISPLAY=:99 && export WINEPREFIX=\$HOME/.wine && cd /opt/mt5-api-bridge && wine \"\$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\" 2>&1 | tee /tmp/mt5_screen.log"

echo "   Waiting 60 seconds for MT5 Terminal to start..."
sleep 60

# Verify MT5 is running
if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal is running"
    pgrep -f "terminal64.exe" | while read pid; do
        echo "   PID: $pid"
    done
else
    echo "❌ MT5 Terminal failed to start"
    if [ -f /tmp/mt5_screen.log ]; then
        echo "   Last 20 lines of startup log:"
        tail -20 /tmp/mt5_screen.log
    fi
    exit 1
fi
echo ""

# Step 5: Wait and test RPyC connection
echo "[5/5] Waiting for MT5 to be ready and testing RPyC..."
echo "===================================================="
echo "   Waiting additional 90 seconds for MT5 Terminal to fully initialize..."
sleep 90

cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

print("   Testing RPyC connection...")
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection established")
    
    print("   Waiting 10 seconds...")
    time.sleep(10)
    
    print("   Attempting to initialize MT5...")
    try:
        initialized = mt5.initialize()
        if initialized:
            print("   ✅ MT5 initialized successfully")
            time.sleep(3)
            
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal info: Build {terminal_info.build}")
                print(f"   ✅ MT5 Terminal is ready!")
                sys.exit(0)
            else:
                print("   ⚠️  terminal_info() is None")
                print("   MT5 may need more time or a login")
                sys.exit(1)
        else:
            error = mt5.last_error()
            print(f"   ⚠️  Initialize returned False: {error}")
            sys.exit(1)
    except Exception as e:
        error_str = str(e).lower()
        if "timeout" in error_str or "expired" in error_str:
            print(f"   ❌ Timeout: {e}")
            print("   MT5 Terminal is not responding to RPyC calls")
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
    echo "=================================="
    echo "✅ MT5 Terminal is ready!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Restart API: sudo systemctl restart mt5-api"
    echo "   2. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   3. Or connect account: curl -X POST 'https://trade.trainflow.dev/api/v1/accounts/connect' ..."
else
    echo "=================================="
    echo "❌ MT5 Terminal is still not ready"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check MT5 screen log: tail -100 /tmp/mt5_screen.log"
    echo "   2. Check RPyC logs: journalctl -u mt5-rpyc -n 50"
    echo "   3. Try connecting via VNC to see if MT5 Terminal GUI is responsive"
    echo "   4. Wait 5-10 more minutes and try again"
fi
echo ""

