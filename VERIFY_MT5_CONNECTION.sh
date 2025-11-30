#!/bin/bash
# Verify MT5 Terminal is running and accessible via RPyC

echo "🔍 Verifying MT5 Connection"
echo "==========================="
echo ""

# Check if MT5 Terminal process is running
echo "[1/4] Checking MT5 Terminal process..."
if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal process is running"
    pgrep -f "terminal64.exe\|terminal.exe" | while read pid; do
        echo "   PID: $pid"
        ps -p $pid -o lstart=,etime=,rss= | head -1
    done
else
    echo "❌ MT5 Terminal process not found"
    echo "   Start it with: ./FIX_MT5_CRASH.sh"
    exit 1
fi
echo ""

# Check screen session
echo "[2/4] Checking screen session..."
if screen -ls | grep -q mt5_terminal; then
    echo "✅ MT5 Terminal screen session exists"
    screen -ls | grep mt5_terminal
else
    echo "⚠️  No screen session found (MT5 may be running directly)"
fi
echo ""

# Check RPyC server
echo "[3/4] Checking RPyC server..."
if systemctl is-active --quiet mt5-rpyc 2>/dev/null || ss -tlnp | grep -q ":8001"; then
    echo "✅ RPyC server is running on port 8001"
    if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
        systemctl status mt5-rpyc --no-pager -l | head -3
    fi
else
    echo "❌ RPyC server is not running"
    echo "   Start it with: systemctl start mt5-rpyc"
    exit 1
fi
echo ""

# Test RPyC connection
echo "[4/4] Testing RPyC connection to MT5..."
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
        print(f"      Path: {terminal_info.path}")
        print(f"      Data Path: {terminal_info.data_path}")
        
        # Try to get account info (may be None if not logged in)
        account = mt5.account_info()
        if account:
            print(f"      ✅ Account logged in:")
            print(f"         Login: {account.login}")
            print(f"         Server: {account.server}")
            print(f"         Balance: {account.balance}")
            print(f"         Equity: {account.equity}")
            print(f"         Margin: {account.margin}")
        else:
            print(f"      ⚠️  Not logged in yet (account_info() returned None)")
            print(f"      You can log in via the API or MT5 terminal")
        
        sys.exit(0)
    else:
        print("   ⚠️  Connected but terminal_info() returned None")
        print("   MT5 may still be initializing")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Connection error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

TEST_RESULT=$?

echo ""
echo "==========================="
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ MT5 Connection Verified!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API endpoint:"
    echo "      curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' \\"
    echo "        -H 'Authorization: Bearer YOUR_TOKEN'"
    echo ""
    echo "   2. View MT5 Terminal screen (if needed):"
    echo "      screen -r mt5_terminal"
    echo "      (Press Ctrl+A then D to detach)"
    echo ""
    echo "   3. View API logs:"
    echo "      journalctl -u mt5-api -f"
else
    echo "⚠️  Connection test failed"
    echo ""
    echo "📋 Troubleshooting:"
    echo "   1. Wait 30-60 seconds for MT5 to fully initialize"
    echo "   2. Check MT5 process: ps aux | grep terminal"
    echo "   3. Check RPyC: systemctl status mt5-rpyc"
    echo "   4. View RPyC logs: journalctl -u mt5-rpyc -n 50"
    echo "   5. Try restarting: ./RESTART_MT5_AND_API.sh"
fi
echo ""

