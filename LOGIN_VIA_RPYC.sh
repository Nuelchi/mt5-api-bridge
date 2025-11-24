#!/bin/bash
# Login to MT5 via RPyC connection (mt5linux)

set -e

MT5_LOGIN="5042856355"
MT5_PASSWORD="V!QzRxQ7"
MT5_SERVER="MetaQuotes-Demo"

echo "🔐 Logging in to MT5 via RPyC"
echo "============================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Check if RPyC server is running
if ! systemctl is-active --quiet mt5-rpyc; then
    echo "⚠️  RPyC server is not running"
    echo "   Starting RPyC server..."
    systemctl start mt5-rpyc
    sleep 5
fi

if ! systemctl is-active --quiet mt5-rpyc; then
    echo "❌ Failed to start RPyC server"
    echo "   Check: systemctl status mt5-rpyc"
    exit 1
fi

echo "✅ RPyC server is running"
echo ""

# Check if MT5 Terminal is running
if ! pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "⚠️  MT5 Terminal is not running"
    echo "   Starting MT5 Terminal..."
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    if [ -f "$MT5_EXE" ]; then
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        echo "   Waiting 20 seconds for MT5 to start..."
        sleep 20
    else
        echo "❌ MT5 Terminal not found: $MT5_EXE"
        exit 1
    fi
fi

echo "✅ MT5 Terminal is running"
echo ""

# Wait for MT5 to be ready via RPyC
echo "⏳ Waiting for MT5 to be ready via RPyC..."
MAX_ATTEMPTS=15
ATTEMPT=0
MT5_READY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "   Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    # Try to connect and check if MT5 is initialized
    python3 -c "
from mt5linux import MetaTrader5
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    # Try to get terminal info - this will work if MT5 is initialized
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print('   ✅ MT5 is ready!')
        exit(0)
    else:
        exit(1)
except Exception as e:
    exit(1)
" 2>/dev/null && {
        MT5_READY=true
        echo "   ✅ MT5 Terminal is ready!"
        break
    }
    
    sleep 3
done

if [ "$MT5_READY" = false ]; then
    echo "⚠️  MT5 Terminal may not be fully ready, but attempting login anyway..."
fi

echo ""
echo "🔑 Attempting login via RPyC..."
echo ""

# Login via RPyC
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    print("Connecting to RPyC server...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("✅ Connected to RPyC server")
    
    # Check if already logged in
    account = mt5.account_info()
    if account and account.login == $MT5_LOGIN:
        print(f"✅ Already logged in!")
        print(f"   Account: {account.login}")
        print(f"   Server: {account.server}")
        print(f"   Balance: {account.balance}")
        sys.exit(0)
    
    # Initialize if not already initialized
    print("Initializing MT5...")
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"⚠️  Initialize returned False: {error}")
        print("   Continuing anyway...")
    
    # Wait a bit
    import time
    time.sleep(2)
    
    # Login
    print(f"Logging in: {int($MT5_LOGIN)} @ {repr('$MT5_SERVER')}...")
    authorized = mt5.login(int($MT5_LOGIN), password=repr('$MT5_PASSWORD').strip("'"), server=repr('$MT5_SERVER').strip("'"))
    
    if authorized:
        account = mt5.account_info()
        if account:
            print(f"✅ Login successful!")
            print(f"   Account: {account.login}")
            print(f"   Server: {account.server}")
            print(f"   Balance: {account.balance}")
            print(f"   Equity: {account.equity}")
            sys.exit(0)
        else:
            print("⚠️  Login authorized but account_info() is None")
            print("   Waiting 5 seconds and retrying...")
            time.sleep(5)
            account = mt5.account_info()
            if account:
                print(f"✅ Account info retrieved!")
                print(f"   Account: {account.login}")
                print(f"   Server: {account.server}")
                print(f"   Balance: {account.balance}")
                sys.exit(0)
            else:
                sys.exit(1)
    else:
        error = mt5.last_error()
        print(f"❌ Login failed: {error}")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("❌ Cannot connect to RPyC server on port 8001")
    print("   Check: systemctl status mt5-rpyc")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Login successful!"
    echo ""
    echo "🧪 Final connection test..."
    echo ""
    
    python3 -c "
from mt5linux import MetaTrader5
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    account = mt5.account_info()
    if account:
        print(f'✅ SUCCESS! MT5 is logged in and accessible!')
        print(f'   Account: {account.login}')
        print(f'   Server: {account.server}')
        print(f'   Balance: {account.balance}')
        print(f'   Equity: {account.equity}')
        print(f'   Margin: {account.margin}')
        print(f'   Free Margin: {account.margin_free}')
    else:
        print('⚠️  Connected but account_info() returned None')
except Exception as e:
    print(f'⚠️  Connection test failed: {e}')
" || echo "⚠️  Final test failed"
    
    echo ""
    echo "✅ Setup complete! You can now run: ./TEST_AND_SETUP.sh"
    exit 0
else
    echo ""
    echo "❌ Login failed"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check if MT5 Terminal is fully started: ps aux | grep terminal64"
    echo "   2. Check RPyC server: systemctl status mt5-rpyc"
    echo "   3. Check MT5 Terminal logs in Wine"
    echo "   4. Try waiting longer (MT5 Terminal can take 30-60 seconds to fully initialize)"
    exit 1
fi

