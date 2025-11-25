#!/bin/bash
# Check Mono installation and try starting MT5 via systemd

set -e

echo "🔍 Checking Mono Installation"
echo "============================="
echo ""

export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"

# Check Mono
MONO_DIR="$WINEPREFIX/drive_c/Program Files/Mono"
if [ -d "$MONO_DIR" ]; then
    echo "✅ Mono directory exists: $MONO_DIR"
    echo "   Contents:"
    ls -la "$MONO_DIR" | head -10
    echo ""
    
    # Check if mono.exe exists
    if [ -f "$MONO_DIR/bin/mono.exe" ]; then
        echo "✅ mono.exe found"
        DISPLAY=:99 wine "$MONO_DIR/bin/mono.exe" --version 2>&1 | head -3 || echo "   ⚠️  Could not run mono.exe"
    else
        echo "❌ mono.exe not found"
    fi
else
    echo "❌ Mono directory not found!"
    echo "   Installing Mono properly..."
    
    # Use the method from CORRECT_MT5_SETUP.sh
    MONO_URL="https://download.mono-project.com/archive/6.12.0/windows-installer/mono-6.12.0.182-x64-0.msi"
    MONO_MSI="/tmp/mono.msi"
    
    echo "   Downloading Mono..."
    wget -q --show-progress "$MONO_URL" -O "$MONO_MSI" || {
        echo "   ❌ Download failed"
        exit 1
    }
    
    echo "   Installing Mono (this may take 2-3 minutes)..."
    DISPLAY=:99 wine msiexec /i "$MONO_MSI" /quiet /norestart
    sleep 30  # Give it time to install
    
    if [ -d "$MONO_DIR" ]; then
        echo "   ✅ Mono installed successfully"
    else
        echo "   ❌ Mono installation may have failed"
    fi
    
    rm -f "$MONO_MSI"
fi

echo ""
echo "🚀 Attempting to Start MT5 Terminal via systemd"
echo "================================================"
echo ""

# Stop any existing MT5 processes
pkill -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
sleep 2

# Start via systemd
echo "Starting MT5 Terminal service..."
systemctl start mt5-terminal
sleep 5

# Check status
if systemctl is-active --quiet mt5-terminal; then
    echo "✅ MT5 Terminal service is running!"
    echo ""
    echo "   Status:"
    systemctl status mt5-terminal --no-pager -l | head -15
    echo ""
    echo "   Recent logs:"
    journalctl -u mt5-terminal -n 20 --no-pager | tail -10
else
    echo "❌ MT5 Terminal service failed to start"
    echo ""
    echo "   Status:"
    systemctl status mt5-terminal --no-pager -l | head -20
    echo ""
    echo "   Recent logs:"
    journalctl -u mt5-terminal -n 30 --no-pager
fi

echo ""
echo "💡 Alternative Approach: Use MT5 without GUI"
echo "============================================="
echo ""
echo "Since MT5 Terminal GUI keeps crashing, we can try using MT5"
echo "programmatically via Windows Python without the GUI."
echo ""
echo "The RPyC server should be able to connect to MT5 even if"
echo "the GUI isn't running, as long as MT5 is initialized."
echo ""
echo "Let's test if we can connect via RPyC:"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    print("Connecting to RPyC server...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("✅ Connected to RPyC server")
    
    # Try to initialize MT5 (this might work even without GUI)
    print("Attempting to initialize MT5...")
    if mt5.initialize():
        print("✅ MT5 initialized successfully!")
        print("   This means MT5 can work without the GUI!")
        
        # Try to login
        print("Attempting login...")
        authorized = mt5.login(5042856355, password="V!QzRxQ7", server="MetaQuotes-Demo")
        if authorized:
            account = mt5.account_info()
            if account:
                print(f"✅ Login successful!")
                print(f"   Account: {account.login}")
                print(f"   Server: {account.server}")
                print(f"   Balance: {account.balance}")
                sys.exit(0)
            else:
                print("⚠️  Login authorized but account_info() is None")
        else:
            error = mt5.last_error()
            print(f"❌ Login failed: {error}")
    else:
        error = mt5.last_error()
        print(f"❌ Initialize failed: {error}")
        print("   MT5 Terminal GUI may be required")
        
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
PYEOF

echo ""
echo "✅ Check complete!"



