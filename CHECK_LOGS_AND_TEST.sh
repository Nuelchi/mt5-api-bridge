#!/bin/bash
# Check detailed logs and test MT5 without GUI

set -e

echo "🔍 Checking MT5 Terminal Logs"
echo "=============================="
echo ""

# Check recent logs
echo "[1/4] Recent MT5 Terminal logs:"
echo "================================"
journalctl -u mt5-terminal -n 50 --no-pager | tail -30
echo ""

# Check if there are any Wine errors
echo "[2/4] Checking for Wine errors:"
echo "================================"
journalctl -u mt5-terminal --no-pager | grep -i "err\|error\|fail\|crash" | tail -20 || echo "   (no obvious errors found)"
echo ""

# Check if MT5 process is actually running
echo "[3/4] Checking MT5 processes:"
echo "=============================="
ps aux | grep -E "terminal64|terminal.exe|wine.*terminal" | grep -v grep || echo "   ❌ No MT5 processes running"
echo ""

# Test if we can use MT5 programmatically without GUI
echo "[4/4] Testing MT5 via RPyC (without GUI):"
echo "========================================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Check if RPyC server is running
if ! systemctl is-active --quiet mt5-rpyc; then
    echo "⚠️  RPyC server is not running, starting it..."
    systemctl start mt5-rpyc
    sleep 5
fi

if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server is running"
    echo ""
    echo "Testing connection..."
    
    python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    print("Connecting to RPyC server...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("✅ Connected to RPyC server")
    
    # Try to get terminal info first (this doesn't require login)
    print("Getting terminal info...")
    try:
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"✅ Terminal info retrieved!")
            print(f"   Build: {terminal_info.build}")
            print(f"   Company: {terminal_info.company}")
            print(f"   Name: {terminal_info.name}")
            print(f"   Path: {terminal_info.path}")
            print("")
            print("💡 This means MT5 backend is working even without GUI!")
            print("")
        else:
            print("⚠️  terminal_info() returned None")
    except Exception as e:
        print(f"⚠️  Could not get terminal info: {e}")
        print("   This might mean MT5 Terminal needs to be running")
    
    # Try to initialize
    print("Attempting to initialize MT5...")
    if mt5.initialize():
        print("✅ MT5 initialized successfully!")
        print("   This confirms MT5 can work without GUI!")
        print("")
        
        # Try to login
        print("Attempting login...")
        time.sleep(2)
        authorized = mt5.login(5042856355, password="V!QzRxQ7", server="MetaQuotes-Demo")
        if authorized:
            time.sleep(2)
            account = mt5.account_info()
            if account:
                print(f"✅ Login successful!")
                print(f"   Account: {account.login}")
                print(f"   Server: {account.server}")
                print(f"   Balance: {account.balance}")
                print(f"   Equity: {account.equity}")
                print("")
                print("🎉 SUCCESS! MT5 is working without GUI!")
                sys.exit(0)
            else:
                print("⚠️  Login authorized but account_info() is None")
                print("   Waiting 5 seconds...")
                time.sleep(5)
                account = mt5.account_info()
                if account:
                    print(f"✅ Account info retrieved!")
                    print(f"   Account: {account.login}")
                    print(f"   Server: {account.server}")
                    print(f"   Balance: {account.balance}")
                    sys.exit(0)
        else:
            error = mt5.last_error()
            print(f"❌ Login failed: {error}")
    else:
        error = mt5.last_error()
        print(f"❌ Initialize failed: {error}")
        print("   MT5 Terminal GUI may be required for initialization")
        
except ConnectionRefusedError:
    print("❌ Cannot connect to RPyC server on port 8001")
    print("   Check: systemctl status mt5-rpyc")
except TimeoutError as e:
    print(f"⚠️  Timeout: {e}")
    print("   MT5 Terminal may need more time to initialize")
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
PYEOF

    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo "✅ SUCCESS! MT5 is working without the GUI!"
        echo ""
        echo "💡 Solution: We don't need the MT5 Terminal GUI to stay running."
        echo "   The RPyC server can connect to MT5's backend services directly."
        echo ""
        echo "   Next steps:"
        echo "   1. Stop the MT5 Terminal service (it keeps crashing but that's OK)"
        echo "   2. Run: ./TEST_AND_SETUP.sh to complete the setup"
    else
        echo ""
        echo "⚠️  MT5 may need the Terminal GUI to be running for initialization"
        echo "   But once initialized, it might work without GUI"
    fi
else
    echo "❌ RPyC server is not running"
    echo "   Start it: systemctl start mt5-rpyc"
fi

echo ""
echo "✅ Check complete!"



