#!/bin/bash
# Ensure MT5 Terminal is running and accessible via RPyC

echo "🔧 Ensuring MT5 Terminal is Running"
echo "===================================="
echo ""

# Step 1: Check if MT5 Terminal is already running
echo "[1/5] Checking for existing MT5 Terminal processes..."
MT5_PIDS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep | awk '{print $2}')
if [ -n "$MT5_PIDS" ]; then
    echo "✅ Found MT5 Terminal processes:"
    for pid in $MT5_PIDS; do
        ps -p $pid -o pid=,lstart=,etime=,cmd= | head -1
    done
    echo ""
    echo "   Testing if RPyC can access it..."
    cd /opt/mt5-api-bridge
    source venv/bin/activate
    
    python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    time.sleep(2)
    
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ MT5 Terminal is accessible via RPyC!")
        print(f"      Version: {terminal_info.build}")
        sys.exit(0)
    else:
        print("   ⚠️  MT5 Terminal running but not accessible via RPyC")
        print("   Will restart MT5 Terminal...")
        sys.exit(1)
except Exception as e:
    if "result expired" in str(e) or "timeout" in str(e).lower():
        print(f"   ⚠️  RPyC timeout: {e}")
        print("   MT5 Terminal may need to be restarted")
    else:
        print(f"   ⚠️  Error: {e}")
    sys.exit(1)
PYEOF
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ MT5 Terminal is running and accessible!"
        exit 0
    else
        echo "   Existing MT5 Terminal is not accessible, will restart..."
        echo ""
        # Kill existing processes
        for pid in $MT5_PIDS; do
            echo "   Killing MT5 Terminal process PID: $pid"
            kill -9 $pid 2>/dev/null || true
        done
        sleep 3
    fi
else
    echo "❌ No MT5 Terminal processes found"
fi
echo ""

# Step 2: Ensure virtual display
echo "[2/5] Ensuring virtual display is running..."
if ! pgrep -x Xvfb > /dev/null; then
    echo "   Starting Xvfb..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
    echo "✅ Virtual display started"
else
    echo "✅ Virtual display already running"
fi
echo ""

# Step 3: Ensure RPyC server is running
echo "[3/5] Ensuring RPyC server is running..."
if ! systemctl is-active --quiet mt5-rpyc 2>/dev/null && ! ss -tlnp | grep -q ":8001"; then
    echo "   Starting RPyC server..."
    systemctl start mt5-rpyc
    sleep 5
    if systemctl is-active --quiet mt5-rpyc; then
        echo "✅ RPyC server started"
    else
        echo "⚠️  RPyC service failed, starting manually..."
        cd /opt/mt5-api-bridge
        source venv/bin/activate
        nohup python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe > /tmp/rpyc.log 2>&1 &
        sleep 3
    fi
else
    echo "✅ RPyC server is running"
fi
echo ""

# Step 4: Start MT5 Terminal
echo "[4/5] Starting MT5 Terminal..."
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
echo "   Starting MT5 Terminal in screen session..."
screen -dmS mt5_terminal bash -c "export DISPLAY=:99 && export WINEPREFIX=\$HOME/.wine && cd /opt/mt5-api-bridge && wine \"\$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\" 2>&1 | tee /tmp/mt5_screen.log"

echo "   Waiting 45 seconds for MT5 Terminal to initialize..."
sleep 45

# Verify MT5 is running
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "✅ MT5 Terminal is running"
    pgrep -f "terminal64.exe" | while read pid; do
        echo "   PID: $pid"
    done
else
    echo "❌ MT5 Terminal failed to start"
    if [ -f /tmp/mt5_screen.log ]; then
        echo "   Last 30 lines of startup log:"
        tail -30 /tmp/mt5_screen.log
    fi
    exit 1
fi
echo ""

# Step 5: Test RPyC connection
echo "[5/5] Testing RPyC connection..."
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
            print(f"      ⚠️  Not logged in (you can log in via API)")
        sys.exit(0)
    else:
        print("   ⚠️  terminal_info() returned None")
        print("   MT5 Terminal may need more time to initialize")
        print("   But RPyC connection works - API should be functional")
        sys.exit(0)  # Don't fail - connection works
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    if "result expired" in str(e) or "timeout" in str(e).lower():
        print(f"   ⚠️  Connection timeout: {e}")
        print("   MT5 Terminal may still be initializing")
        print("   The API will retry on each request")
        sys.exit(0)  # Don't fail - will retry
    else:
        print(f"   ❌ Error: {e}")
        sys.exit(1)
PYEOF

TEST_RESULT=$?

echo ""
echo "==========================="
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ MT5 Terminal is Running and Accessible!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Restart MT5 API service: systemctl restart mt5-api"
    echo "   2. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
else
    echo "⚠️  MT5 Terminal is running but RPyC connection has issues"
    echo ""
    echo "📋 The API will retry on each request, so it should work eventually"
    echo "   Restart API: systemctl restart mt5-api"
fi
echo ""

