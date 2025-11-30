#!/bin/bash
# Restart MT5 Terminal so RPyC can access it

echo "🔄 Restarting MT5 Terminal for RPyC"
echo "===================================="
echo ""

# Step 1: Kill existing MT5 Terminal processes
echo "[1/4] Stopping existing MT5 Terminal processes..."
MT5_PIDS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep | awk '{print $2}')
if [ -n "$MT5_PIDS" ]; then
    for pid in $MT5_PIDS; do
        echo "   Killing MT5 Terminal process PID: $pid"
        kill -9 $pid 2>/dev/null || true
    done
    sleep 3
    echo "✅ MT5 Terminal processes stopped"
else
    echo "✅ No MT5 Terminal processes to stop"
fi
echo ""

# Step 2: Ensure virtual display is running
echo "[2/4] Ensuring virtual display is running..."
if ! pgrep -x Xvfb > /dev/null; then
    echo "   Starting Xvfb..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
    echo "✅ Virtual display started"
else
    echo "✅ Virtual display already running"
fi
echo ""

# Step 3: Start MT5 Terminal in screen session
echo "[3/4] Starting MT5 Terminal in screen session..."
export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ ! -f "$MT5FILE" ]; then
    echo "❌ MT5 Terminal not found at: $MT5FILE"
    exit 1
fi

# Kill any existing screen session
screen -S mt5_terminal -X quit 2>/dev/null || true
sleep 2

# Start MT5 in screen
echo "   Starting MT5 Terminal..."
screen -dmS mt5_terminal bash -c "export DISPLAY=:99 && export WINEPREFIX=\$HOME/.wine && cd /opt/mt5-api-bridge && wine \"\$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\" 2>&1 | tee /tmp/mt5_screen.log"

echo "   Waiting 30 seconds for MT5 Terminal to initialize..."
sleep 30

# Verify MT5 is running
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "✅ MT5 Terminal is running"
    pgrep -f "terminal64.exe" | while read pid; do
        echo "   PID: $pid"
        ps -p $pid -o lstart=,etime= | head -1
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

# Step 4: Wait and test RPyC connection
echo "[4/4] Testing RPyC connection to MT5..."
echo "   Waiting additional 30 seconds for MT5 to fully initialize..."
sleep 30

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
        print(f"   ✅ MT5 Terminal is accessible via RPyC!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        
        account = mt5.account_info()
        if account:
            print(f"      ✅ Account logged in: {account.login} @ {account.server}")
            print(f"      Balance: {account.balance}")
        else:
            print(f"      ⚠️  Not logged in (you can log in via API)")
        sys.exit(0)
    else:
        print("   ❌ terminal_info() still returns None")
        print("   MT5 Terminal may need more time to initialize")
        print("   Try waiting another 30 seconds and test again")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    sys.exit(1)
PYEOF

TEST_RESULT=$?

echo ""
echo "==========================="
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ MT5 Terminal Restarted and Accessible via RPyC!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   2. If not logged in, log in via API endpoint"
    echo "   3. View MT5 screen: screen -r mt5_terminal (Ctrl+A then D to detach)"
else
    echo "⚠️  MT5 Terminal restarted but RPyC can't access it yet"
    echo ""
    echo "📋 Try:"
    echo "   1. Wait another 30 seconds: sleep 30 && ./VERIFY_MT5_CONNECTION.sh"
    echo "   2. Check MT5 screen log: tail -50 /tmp/mt5_screen.log"
    echo "   3. Check RPyC logs: journalctl -u mt5-rpyc -n 30"
fi
echo ""

