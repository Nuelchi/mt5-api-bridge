#!/bin/bash
# Use the existing MT5 Terminal process and complete setup

set -e

echo "🎯 Using Existing MT5 Terminal Process"
echo "======================================"
echo ""

# Stop the crashing systemd service
echo "[1/5] Stopping crashing MT5 Terminal service..."
systemctl stop mt5-terminal 2>/dev/null || true
systemctl disable mt5-terminal 2>/dev/null || true
echo "✅ Service stopped (we'll use the existing process instead)"
echo ""

# Check existing MT5 process
echo "[2/5] Checking existing MT5 Terminal process..."
EXISTING_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$EXISTING_PID" ]; then
    echo "✅ Found MT5 Terminal process: PID $EXISTING_PID"
    ps aux | grep $EXISTING_PID | grep -v grep
    echo ""
    echo "   This process has been running since:"
    ps -p $EXISTING_PID -o lstart=
    echo ""
else
    echo "❌ No MT5 Terminal process found"
    echo "   Starting MT5 Terminal manually..."
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
    sleep 15
    EXISTING_PID=$(pgrep -f "terminal64.exe" | head -1)
    if [ -n "$EXISTING_PID" ]; then
        echo "✅ MT5 Terminal started: PID $EXISTING_PID"
    else
        echo "❌ Failed to start MT5 Terminal"
        exit 1
    fi
fi

echo ""

# Ensure RPyC server is running
echo "[3/5] Ensuring RPyC server is running..."
if ! systemctl is-active --quiet mt5-rpyc; then
    echo "   Starting RPyC server..."
    systemctl start mt5-rpyc
    sleep 5
fi

if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server is running"
else
    echo "❌ RPyC server failed to start"
    exit 1
fi

echo ""

# Wait for MT5 to be ready and login
echo "[4/5] Waiting for MT5 to be ready and logging in..."
echo "   (This may take 30-60 seconds)"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

MAX_ATTEMPTS=20
ATTEMPT=0
SUCCESS=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "   Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Try to get terminal info first (quick check)
    try:
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"   ✅ Terminal ready (Build: {terminal_info.build})")
        else:
            print("   ⏳ Terminal not ready yet...")
            sys.exit(2)  # Retry
    except:
        print("   ⏳ Terminal not ready yet...")
        sys.exit(2)  # Retry
    
    # Initialize
    print("   Initializing MT5...")
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False: {error}")
        print("   Continuing anyway...")
    
    time.sleep(3)
    
    # Login
    print("   Logging in...")
    authorized = mt5.login(5042856355, password="V!QzRxQ7", server="MetaQuotes-Demo")
    
    if authorized:
        time.sleep(3)
        account = mt5.account_info()
        if account:
            print(f"   ✅ Login successful!")
            print(f"      Account: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
            print(f"      Equity: {account.equity}")
            sys.exit(0)
        else:
            print("   ⏳ Login authorized, waiting for account info...")
            time.sleep(5)
            account = mt5.account_info()
            if account:
                print(f"   ✅ Account info retrieved!")
                print(f"      Account: {account.login}")
                print(f"      Server: {account.server}")
                print(f"      Balance: {account.balance}")
                sys.exit(0)
            else:
                sys.exit(2)  # Retry
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Login failed: {error}")
        sys.exit(2)  # Retry
        
except TimeoutError:
    print("   ⏳ Timeout - MT5 may still be initializing...")
    sys.exit(2)  # Retry
except Exception as e:
    print(f"   ⏳ Error: {e}")
    sys.exit(2)  # Retry
PYEOF

    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        SUCCESS=true
        break
    elif [ $EXIT_CODE -eq 2 ]; then
        echo "   ⏳ Waiting 5 seconds before retry..."
        sleep 5
        continue
    else
        echo "   ⚠️  Unexpected error, retrying..."
        sleep 5
        continue
    fi
done

echo ""

if [ "$SUCCESS" = true ]; then
    echo "[5/5] Final verification..."
    echo "=========================="
    echo ""
    
    python3 -c "
from mt5linux import MetaTrader5
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    account = mt5.account_info()
    if account:
        print(f'✅ SUCCESS! MT5 is fully operational!')
        print(f'   Account: {account.login}')
        print(f'   Server: {account.server}')
        print(f'   Balance: {account.balance}')
        print(f'   Equity: {account.equity}')
        print(f'   Margin: {account.margin}')
        print(f'   Free Margin: {account.margin_free}')
    else:
        print('⚠️  Connected but account_info() returned None')
except Exception as e:
    print(f'⚠️  Verification failed: {e}')
"
    
    echo ""
    echo "✅ MT5 is ready!"
    echo ""
    echo "📋 Summary:"
    echo "   - MT5 Terminal: Running (PID $EXISTING_PID)"
    echo "   - RPyC Server: Running"
    echo "   - Login: ✅ Successful"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Run: ./TEST_AND_SETUP.sh"
    echo "      This will start the API service, configure Nginx, and set up SSL"
    echo ""
else
    echo "❌ Failed to login after $MAX_ATTEMPTS attempts"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check if MT5 Terminal is fully loaded: ps aux | grep terminal64"
    echo "   2. Check RPyC server: systemctl status mt5-rpyc"
    echo "   3. Try waiting longer (MT5 Terminal can take 60+ seconds to fully initialize)"
    echo "   4. Check if MT5 Terminal needs manual login via GUI"
    exit 1
fi

