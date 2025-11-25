#!/bin/bash
# Wait for MT5 Terminal to fully start, then login via RPyC

set -e

MT5_LOGIN="5042856355"
MT5_PASSWORD="V!QzRxQ7"
MT5_SERVER="MetaQuotes-Demo"

echo "⏳ Waiting for MT5 Terminal to fully start"
echo "==========================================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Ensure RPyC server is running
if ! systemctl is-active --quiet mt5-rpyc; then
    echo "Starting RPyC server..."
    systemctl start mt5-rpyc
    sleep 5
fi

# Ensure MT5 Terminal is running
if ! pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "Starting MT5 Terminal..."
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    if [ -f "$MT5_EXE" ]; then
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        echo "✅ MT5 Terminal started"
    fi
fi

echo "✅ MT5 Terminal process is running"
echo ""
echo "⏳ Waiting 60 seconds for MT5 Terminal to fully initialize..."
echo "   (MT5 Terminal can take 30-60 seconds to be ready)"
echo ""

# Wait longer - MT5 Terminal needs time to fully load
for i in {1..12}; do
    echo -n "   Waiting... ($((i*5))s) "
    sleep 5
    
    # Check if MT5 process is still running
    if ! pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
        echo ""
        echo "⚠️  MT5 Terminal process died, restarting..."
        export DISPLAY=:99
        export WINEPREFIX="$HOME/.wine"
        MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        sleep 10
    else
        echo "✅"
    fi
done

echo ""
echo "🔑 Attempting login via RPyC..."
echo ""

# Try login with retries
MAX_RETRIES=5
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    RETRY=$((RETRY + 1))
    echo "   Attempt $RETRY/$MAX_RETRIES..."
    
    python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   Connecting to RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected")
    
    # Check if already logged in
    try:
        account = mt5.account_info()
        if account and account.login == $MT5_LOGIN:
            print(f"   ✅ Already logged in!")
            print(f"      Account: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
            sys.exit(0)
    except:
        pass
    
    # Try to initialize (with timeout handling)
    print("   Initializing MT5...")
    try:
        # Try a simple call first to see if MT5 is ready
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"   ✅ MT5 Terminal is ready (Build: {terminal_info.build})")
    except Exception as e:
        print(f"   ⚠️  Terminal not ready yet: {e}")
        if "$RETRY" == "$MAX_RETRIES":
            print("   ❌ MT5 Terminal still not ready after all retries")
            sys.exit(1)
        sys.exit(2)  # Exit code 2 = retry
    
    # Initialize
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False: {error}")
        print("   Continuing with login attempt...")
    
    time.sleep(2)
    
    # Login
    print(f"   Logging in: {int($MT5_LOGIN)} @ {repr('$MT5_SERVER')}...")
    authorized = mt5.login(int($MT5_LOGIN), password=repr('$MT5_PASSWORD').strip("'"), server=repr('$MT5_SERVER').strip("'"))
    
    if authorized:
        time.sleep(2)  # Wait for login to complete
        account = mt5.account_info()
        if account:
            print(f"   ✅ Login successful!")
            print(f"      Account: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
            print(f"      Equity: {account.equity}")
            sys.exit(0)
        else:
            print("   ⚠️  Login authorized but account_info() is None")
            print("   Waiting 5 seconds...")
            time.sleep(5)
            account = mt5.account_info()
            if account:
                print(f"   ✅ Account info retrieved!")
                print(f"      Account: {account.login}")
                print(f"      Server: {account.server}")
                print(f"      Balance: {account.balance}")
                sys.exit(0)
            else:
                if "$RETRY" == "$MAX_RETRIES":
                    print("   ❌ Login failed - account_info() still None")
                    sys.exit(1)
                sys.exit(2)  # Retry
    else:
        error = mt5.last_error()
        print(f"   ❌ Login failed: {error}")
        if "$RETRY" == "$MAX_RETRIES":
            sys.exit(1)
        sys.exit(2)  # Retry
        
except ConnectionRefusedError:
    print("   ❌ Cannot connect to RPyC server")
    sys.exit(1)
except TimeoutError as e:
    print(f"   ⚠️  Timeout: {e}")
    if "$RETRY" == "$MAX_RETRIES":
        print("   ❌ Timeout after all retries")
        sys.exit(1)
    sys.exit(2)  # Retry
except Exception as e:
    print(f"   ⚠️  Error: {e}")
    if "$RETRY" == "$MAX_RETRIES":
        print("   ❌ Failed after all retries")
        sys.exit(1)
    sys.exit(2)  # Retry
PYEOF

    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
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
"
        
        echo ""
        echo "✅ Setup complete! You can now run: ./TEST_AND_SETUP.sh"
        exit 0
    elif [ $EXIT_CODE -eq 2 ]; then
        echo "   ⏳ Retrying in 10 seconds..."
        sleep 10
        continue
    else
        echo "   ❌ Login failed"
        if [ $RETRY -eq $MAX_RETRIES ]; then
            echo ""
            echo "❌ Failed after $MAX_RETRIES attempts"
            echo ""
            echo "💡 Troubleshooting:"
            echo "   1. Check MT5 Terminal: ps aux | grep terminal64"
            echo "   2. Check RPyC server: systemctl status mt5-rpyc"
            echo "   3. Check MT5 Terminal logs"
            echo "   4. Try manually logging in to MT5 Terminal via VNC/X11"
            exit 1
        fi
    fi
done



