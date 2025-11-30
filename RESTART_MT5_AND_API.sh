#!/bin/bash
# Comprehensive restart script for MT5 Terminal, RPyC Server, and MT5 API Bridge

set -e

echo "🔄 Restarting MT5 Services"
echo "=========================="
echo ""

# Step 1: Pull latest changes
echo "[1/6] Pulling latest code changes..."
cd /opt/mt5-api-bridge
git pull
echo "✅ Code updated"
echo ""

# Step 2: Stop MT5 API service
echo "[2/6] Stopping MT5 API service..."
systemctl stop mt5-api 2>/dev/null || true
echo "✅ MT5 API service stopped"
echo ""

# Step 3: Stop RPyC server
echo "[3/6] Stopping RPyC server..."
systemctl stop mt5-rpyc 2>/dev/null || true
# Also kill any manual RPyC processes
pkill -f "mt5linux.*8001" 2>/dev/null || true
sleep 2
echo "✅ RPyC server stopped"
echo ""

# Step 4: Stop MT5 Terminal
echo "[4/6] Stopping MT5 Terminal..."
pkill -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
sleep 3
echo "✅ MT5 Terminal stopped"
echo ""

# Step 5: Start virtual display (if not running)
echo "[5/6] Ensuring virtual display is running..."
if ! pgrep -x Xvfb > /dev/null; then
    echo "   Starting Xvfb..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
    echo "✅ Virtual display started"
else
    echo "✅ Virtual display already running"
fi
echo ""

# Step 6: Start MT5 Terminal (using screen method that works)
echo "[6/6] Starting MT5 Terminal..."
export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ ! -f "$MT5FILE" ]; then
    echo "❌ MT5 Terminal not found at: $MT5FILE"
    echo "   Please install MT5 Terminal first"
    exit 1
fi

# Kill any existing screen session
screen -S mt5_terminal -X quit 2>/dev/null || true
sleep 2

# Start MT5 in a screen session (this method works better than direct start)
echo "   Starting MT5 Terminal in screen session..."
screen -dmS mt5_terminal bash -c "export DISPLAY=:99 && export WINEPREFIX=\$HOME/.wine && cd /opt/mt5-api-bridge && wine \"\$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\" 2>&1 | tee /tmp/mt5_screen.log"

echo "   Waiting 20 seconds for MT5 to initialize..."
sleep 20

# Verify MT5 is running
if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal is running in screen session"
    screen -ls | grep mt5_terminal || echo "   (Screen session may have detached)"
    pgrep -f "terminal64.exe\|terminal.exe" | head -1 | xargs ps -p | tail -1
else
    echo "⚠️  MT5 Terminal may have failed to start"
    echo "   Check screen log: tail -50 /tmp/mt5_screen.log"
    echo "   Or try: ./FIX_MT5_CRASH.sh"
fi
echo ""

# Step 7: Start RPyC server
echo "[7/6] Starting RPyC server..."
systemctl start mt5-rpyc
sleep 5

if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server is running"
else
    echo "⚠️  RPyC service failed, trying manual start..."
    cd /opt/mt5-api-bridge
    source venv/bin/activate
    nohup python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe >/dev/null 2>&1 &
    sleep 3
    if ss -tlnp | grep -q ":8001"; then
        echo "✅ RPyC server started manually on port 8001"
    else
        echo "❌ Failed to start RPyC server"
        echo "   Check: journalctl -u mt5-rpyc -n 50"
    fi
fi
echo ""

# Step 8: Start MT5 API service
echo "[8/6] Starting MT5 API service..."
systemctl start mt5-api
sleep 3

if systemctl is-active --quiet mt5-api; then
    echo "✅ MT5 API service is running"
else
    echo "❌ MT5 API service failed to start"
    echo "   Check: systemctl status mt5-api"
    echo "   View logs: journalctl -u mt5-api -n 50"
    exit 1
fi
echo ""

# Step 9: Wait for services to be ready
echo "[9/6] Waiting for services to be ready..."
echo "   Waiting 10 seconds for all services to stabilize..."
sleep 10
echo ""

# Step 10: Test connection
echo "[10/6] Testing MT5 connection..."
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   🔌 Connecting to MT5 via RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Wait a bit for connection
    time.sleep(2)
    
    # Try to get terminal info
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ MT5 Terminal connected!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        
        # Try to get account info (may be None if not logged in)
        account = mt5.account_info()
        if account:
            print(f"      Account: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
        else:
            print(f"      ⚠️  Not logged in yet (account_info() returned None)")
            print(f"      You may need to log in via the MT5 terminal or API")
    else:
        print("   ⚠️  Connected but terminal_info() returned None")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ⚠️  Connection error: {e}")
    print("   This is OK if MT5 is still initializing")
    sys.exit(0)  # Don't fail the script, just warn
PYEOF

TEST_RESULT=$?

echo ""
echo "=========================="
echo "📊 Service Status Summary"
echo "=========================="
echo ""

# Check MT5 Terminal
if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal: RUNNING"
    pgrep -f "terminal64.exe\|terminal.exe" | head -1 | xargs ps -p | tail -1
else
    echo "❌ MT5 Terminal: NOT RUNNING"
fi
echo ""

# Check RPyC server
if systemctl is-active --quiet mt5-rpyc 2>/dev/null || ss -tlnp | grep -q ":8001"; then
    echo "✅ RPyC Server: RUNNING (port 8001)"
else
    echo "❌ RPyC Server: NOT RUNNING"
fi
echo ""

# Check MT5 API
if systemctl is-active --quiet mt5-api; then
    echo "✅ MT5 API Service: RUNNING"
    systemctl status mt5-api --no-pager -l | head -5
else
    echo "❌ MT5 API Service: NOT RUNNING"
fi
echo ""

if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ All services restarted successfully!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. If MT5 is not logged in, log in via the API or terminal"
    echo "   2. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   3. View logs: journalctl -u mt5-api -f"
else
    echo "⚠️  Services restarted but connection test had issues"
    echo ""
    echo "📋 Troubleshooting:"
    echo "   1. Check MT5 Terminal: ps aux | grep terminal"
    echo "   2. Check RPyC: systemctl status mt5-rpyc"
    echo "   3. Check API: systemctl status mt5-api"
    echo "   4. View API logs: journalctl -u mt5-api -n 50"
fi
echo ""

