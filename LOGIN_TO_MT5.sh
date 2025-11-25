#!/bin/bash
# Programmatically login to MT5 Terminal using Windows Python

set -e

WINEPREFIX="$HOME/.wine"
MT5_LOGIN="5042856355"
MT5_PASSWORD="V!QzRxQ7"
MT5_SERVER="MetaQuotes-Demo"

echo "🔐 Logging in to MT5 Terminal"
echo "=============================="
echo ""

export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"

# Check if MT5 Terminal is running
if ! pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "⚠️  MT5 Terminal is not running"
    echo "   Starting MT5 Terminal..."
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    if [ -f "$MT5_EXE" ]; then
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        echo "   Waiting 15 seconds for MT5 to start..."
        sleep 15
    else
        echo "❌ MT5 Terminal not found: $MT5_EXE"
        exit 1
    fi
fi

echo "✅ MT5 Terminal is running"
echo ""

# Wait for MT5 to be ready (check multiple times)
echo "⏳ Waiting for MT5 Terminal to be ready..."
MAX_ATTEMPTS=10
ATTEMPT=0
MT5_READY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "   Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    # Try to initialize MT5
    WIN_PYTHON="$WINEPREFIX/drive_c/Program Files (x86)/Python39-32/python.exe"
    if [ -f "$WIN_PYTHON" ]; then
        # Create a test script
        cat > /tmp/mt5_check.py <<PYEOF
import sys
import time
sys.path.insert(0, r'$WINEPREFIX/drive_c/Program Files (x86)/Python39-32/Lib/site-packages')
try:
    import MetaTrader5 as mt5
    if mt5.initialize():
        mt5.shutdown()
        sys.exit(0)
    else:
        sys.exit(1)
except Exception as e:
    sys.exit(1)
PYEOF
        
        if DISPLAY=:99 wine "$WIN_PYTHON" /tmp/mt5_check.py 2>/dev/null; then
            MT5_READY=true
            echo "   ✅ MT5 Terminal is ready!"
            break
        fi
    fi
    
    sleep 3
done

rm -f /tmp/mt5_check.py

if [ "$MT5_READY" = false ]; then
    echo "⚠️  MT5 Terminal may not be fully ready, but attempting login anyway..."
fi

echo ""
echo "🔑 Attempting login..."
echo ""

# Create login script
cat > /tmp/mt5_login.py <<PYEOF
import sys
import time
sys.path.insert(0, r'$WINEPREFIX/drive_c/Program Files (x86)/Python39-32/Lib/site-packages')

try:
    import MetaTrader5 as mt5
    
    # Initialize MT5
    print("Initializing MT5...")
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"❌ Initialize failed: {error}")
        sys.exit(1)
    
    print("✅ MT5 initialized")
    
    # Wait a bit for MT5 to be fully ready
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
            mt5.shutdown()
            sys.exit(0)
        else:
            print("⚠️  Login authorized but account_info() is None")
            mt5.shutdown()
            sys.exit(1)
    else:
        error = mt5.last_error()
        print(f"❌ Login failed: {error}")
        mt5.shutdown()
        sys.exit(1)
        
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

# Run login script
WIN_PYTHON="$WINEPREFIX/drive_c/Program Files (x86)/Python39-32/python.exe"
if [ -f "$WIN_PYTHON" ]; then
    DISPLAY=:99 wine "$WIN_PYTHON" /tmp/mt5_login.py
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Login successful!"
        echo ""
        echo "🧪 Testing connection via RPyC..."
        echo ""
        
        cd /opt/mt5-api-bridge
        source venv/bin/activate
        
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
    else:
        print('⚠️  Connected but account_info() returned None')
except Exception as e:
    print(f'⚠️  RPyC connection test: {e}')
" || echo "⚠️  RPyC test failed"
        
        rm -f /tmp/mt5_login.py
        exit 0
    else
        echo ""
        echo "❌ Login failed"
        rm -f /tmp/mt5_login.py
        exit 1
    fi
else
    echo "❌ Windows Python not found: $WIN_PYTHON"
    rm -f /tmp/mt5_login.py
    exit 1
fi



