#!/bin/bash
# Install MT5 Terminal on headless VPS using virtual display

set -e

echo "🔧 Installing MT5 Terminal (Headless)"
echo "===================================="

# Check if Xvfb is running
if ! pgrep -x Xvfb > /dev/null; then
    echo "⚠️  Xvfb not running, starting it..."
    systemctl start xvfb || {
        Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
        sleep 2
    }
fi

export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="

# Download MT5 installer if not present
cd /tmp
if [ ! -f "mt5setup.exe" ]; then
    echo "📥 Downloading MT5 Terminal installer..."
    wget -O mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
fi

echo ""
echo "📦 Installing MT5 Terminal (this may take a few minutes)..."
echo "   Running installer with virtual display..."

# Run installer with silent flags if possible, otherwise interactive
WINEDLLOVERRIDES="mscoree,mshtml=" DISPLAY=:99 wine mt5setup.exe /S 2>&1 | tee /tmp/mt5_install.log || {
    echo "⚠️  Silent install failed, trying interactive..."
    echo "   Note: Installation will run in background with virtual display"
    WINEDLLOVERRIDES="mscoree,mshtml=" DISPLAY=:99 wine mt5setup.exe 2>&1 | tee /tmp/mt5_install.log &
    INSTALL_PID=$!
    
    echo "   Installation started (PID: $INSTALL_PID)"
    echo "   Waiting 60 seconds for installation to complete..."
    sleep 60
    
    # Check if process is still running
    if ps -p $INSTALL_PID > /dev/null; then
        echo "   Installation still running, waiting another 60 seconds..."
        sleep 60
    fi
}

# Wait a bit more
sleep 10

# Find MT5 installation
echo ""
echo "🔍 Searching for MT5 Terminal installation..."
MT5_FOUND=$(find ~/.wine -name "terminal64.exe" -o -name "terminal.exe" 2>/dev/null | head -1)

if [ -n "$MT5_FOUND" ]; then
    echo "✅ MT5 Terminal found at: $MT5_FOUND"
    MT5_DIR=$(dirname "$MT5_FOUND")
    
    # Update startup script
    cat > /opt/start_mt5.sh <<EOF
#!/bin/bash
# Start MT5 Terminal (headless)

export DISPLAY=:99
export WINEPREFIX="\$HOME/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="

# Ensure Xvfb is running
if ! pgrep -x Xvfb > /dev/null; then
    systemctl start xvfb || Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
fi

MT5_DIR="$MT5_DIR"

if [ -f "\$MT5_DIR/terminal64.exe" ]; then
    cd "\$MT5_DIR"
    wine terminal64.exe
elif [ -f "\$MT5_DIR/terminal.exe" ]; then
    cd "\$MT5_DIR"
    wine terminal.exe
else
    echo "❌ MT5 Terminal executable not found"
    exit 1
fi
EOF
    chmod +x /opt/start_mt5.sh
    echo "✅ Startup script created: /opt/start_mt5.sh"
else
    echo "⚠️  MT5 Terminal not found after installation"
    echo "   Check installation log: /tmp/mt5_install.log"
    echo "   You may need to install manually or check Wine prefix"
fi

echo ""
echo "✅ Installation process complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Start MT5 Terminal: /opt/start_mt5.sh &"
echo "   2. Log in to your MT5 account (may need VNC or remote desktop)"
echo "   3. Install RPC server EA in MT5"
echo "   4. Test connection: python3 test_mt5_connection_v3.py"
echo ""

