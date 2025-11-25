#!/bin/bash
# Configure MT5 Terminal for auto-login

set -e

WINEPREFIX="$HOME/.wine"
MT5_LOGIN="5042856355"
MT5_PASSWORD="V!QzRxQ7"
MT5_SERVER="MetaQuotes-Demo"

echo "🔐 Configuring MT5 Auto-Login"
echo "=============================="
echo ""

# Find MT5 data directory
MT5_DATA_DIRS=(
    "$WINEPREFIX/drive_c/users/Public/Application Data/MetaTrader 5"
    "$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
    "$WINEPREFIX/drive_c/users/$USER/Application Data/MetaTrader 5"
)

MT5_DATA_DIR=""
for dir in "${MT5_DATA_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        MT5_DATA_DIR="$dir"
        echo "✅ Found MT5 directory: $MT5_DATA_DIR"
        break
    fi
done

if [ -z "$MT5_DATA_DIR" ]; then
    echo "⚠️  MT5 data directory not found, creating default..."
    MT5_DATA_DIR="$WINEPREFIX/drive_c/users/Public/Application Data/MetaTrader 5"
    mkdir -p "$MT5_DATA_DIR"
fi

# Create config directory
CONFIG_DIR="$MT5_DATA_DIR/config"
mkdir -p "$CONFIG_DIR"

echo ""
echo "📝 Creating login configuration..."
echo ""

# Method 1: Create common.ini with auto-login
COMMON_INI="$CONFIG_DIR/common.ini"
cat > "$COMMON_INI" <<EOF
[Common]
Login=$MT5_LOGIN
Password=$MT5_PASSWORD
Server=$MT5_SERVER
AutoLogin=1
SavePassword=1
EOF

echo "✅ Created: $COMMON_INI"

# Method 2: Create servers.ini with server info
SERVERS_INI="$CONFIG_DIR/servers.ini"
if [ ! -f "$SERVERS_INI" ]; then
    cat > "$SERVERS_INI" <<EOF
[$MT5_SERVER]
Name=$MT5_SERVER
Address=$MT5_SERVER
Type=0
Description=MetaQuotes Demo Server
EOF
    echo "✅ Created: $SERVERS_INI"
fi

# Method 3: Try to find and update terminal.ini
TERMINAL_INI="$MT5_DATA_DIR/terminal.ini"
if [ -f "$TERMINAL_INI" ]; then
    echo "📝 Updating existing terminal.ini..."
    # Backup
    cp "$TERMINAL_INI" "$TERMINAL_INI.bak"
    
    # Update or add login settings
    if grep -q "^Login=" "$TERMINAL_INI"; then
        sed -i "s/^Login=.*/Login=$MT5_LOGIN/" "$TERMINAL_INI"
    else
        echo "Login=$MT5_LOGIN" >> "$TERMINAL_INI"
    fi
    
    if grep -q "^Password=" "$TERMINAL_INI"; then
        sed -i "s/^Password=.*/Password=$MT5_PASSWORD/" "$TERMINAL_INI"
    else
        echo "Password=$MT5_PASSWORD" >> "$TERMINAL_INI"
    fi
    
    if grep -q "^Server=" "$TERMINAL_INI"; then
        sed -i "s/^Server=.*/Server=$MT5_SERVER/" "$TERMINAL_INI"
    else
        echo "Server=$MT5_SERVER" >> "$TERMINAL_INI"
    fi
    
    echo "✅ Updated: $TERMINAL_INI"
else
    echo "📝 Creating terminal.ini..."
    cat > "$TERMINAL_INI" <<EOF
[Common]
Login=$MT5_LOGIN
Password=$MT5_PASSWORD
Server=$MT5_SERVER
AutoLogin=1
SavePassword=1
EOF
    echo "✅ Created: $TERMINAL_INI"
fi

# Method 4: Use Windows Python to programmatically login via MetaTrader5 library
echo ""
echo "🔄 Attempting programmatic login via Python..."
echo ""

WIN_PYTHON="$WINEPREFIX/drive_c/Program Files (x86)/Python39-32/python.exe"
if [ -f "$WIN_PYTHON" ]; then
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    
    # Create a Python script to login
    cat > /tmp/mt5_login.py <<PYEOF
import sys
sys.path.insert(0, r'$WINEPREFIX/drive_c/Program Files (x86)/Python39-32/Lib/site-packages')
try:
    import MetaTrader5 as mt5
    if not mt5.initialize():
        print(f"Initialize failed: {mt5.last_error()}")
        sys.exit(1)
    
    authorized = mt5.login($MT5_LOGIN, password="$MT5_PASSWORD", server="$MT5_SERVER")
    if authorized:
        account = mt5.account_info()
        print(f"✅ Login successful!")
        print(f"   Account: {account.login}")
        print(f"   Server: {account.server}")
        print(f"   Balance: {account.balance}")
        mt5.shutdown()
        sys.exit(0)
    else:
        print(f"❌ Login failed: {mt5.last_error()}")
        mt5.shutdown()
        sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
PYEOF

    DISPLAY=:99 wine "$WIN_PYTHON" /tmp/mt5_login.py && {
        echo "✅ Programmatic login successful!"
        rm -f /tmp/mt5_login.py
    } || {
        echo "⚠️  Programmatic login failed, but config files are set"
        echo "   MT5 Terminal should auto-login on next restart"
        rm -f /tmp/mt5_login.py
    }
else
    echo "⚠️  Windows Python not found, skipping programmatic login"
fi

echo ""
echo "🔄 Restarting MT5 Terminal..."
echo ""

# Kill existing MT5 Terminal
pkill -f "terminal64.exe\|terminal.exe" || true
sleep 2

# Start MT5 Terminal with auto-login
export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"
MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ -f "$MT5_EXE" ]; then
    echo "Starting MT5 Terminal..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
    sleep 10
    
    echo "✅ MT5 Terminal restarted"
    echo ""
    echo "🧪 Testing connection in 5 seconds..."
    sleep 5
    
    cd /opt/mt5-api-bridge
    source venv/bin/activate
    
    python3 -c "
from mt5linux import MetaTrader5
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    account = mt5.account_info()
    if account:
        print(f'✅ SUCCESS! MT5 is logged in!')
        print(f'   Account: {account.login}')
        print(f'   Server: {account.server}')
        print(f'   Balance: {account.balance}')
    else:
        print('⚠️  Connected but account_info() returned None')
        print('   MT5 Terminal may still be initializing')
except Exception as e:
    print(f'⚠️  Connection test: {e}')
    print('   This is normal if MT5 Terminal is still starting')
" || echo "⚠️  Connection test failed - MT5 may still be initializing"
    
else
    echo "❌ MT5 Terminal executable not found: $MT5_EXE"
fi

echo ""
echo "✅ Auto-login configuration complete!"
echo ""
echo "📋 Summary:"
echo "   Login: $MT5_LOGIN"
echo "   Server: $MT5_SERVER"
echo "   Config files created/updated"
echo ""
echo "💡 If login didn't work automatically:"
echo "   1. Wait 30 seconds for MT5 Terminal to fully start"
echo "   2. Run: ./TEST_AND_SETUP.sh"
echo ""



