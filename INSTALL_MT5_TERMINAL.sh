#!/bin/bash
# Install MT5 Terminal on Linux using Wine

set -e

echo "🔧 Installing MT5 Terminal on Linux"
echo "===================================="

# Check if Wine is installed
if ! command -v wine &> /dev/null; then
    echo "📦 Installing Wine..."
    apt update
    apt install -y wine wine64 winetricks
    
    # Initialize Wine (creates ~/.wine)
    echo "🍷 Initializing Wine..."
    WINEDLLOVERRIDES="mscoree,mshtml=" winecfg -v win10 2>/dev/null || true
else
    echo "✅ Wine already installed: $(wine --version)"
fi

# Create MT5 directory
MT5_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5"
mkdir -p "$MT5_DIR"

echo ""
echo "📥 Downloading MT5 Terminal installer..."
cd /tmp

# Download MT5 installer
if [ ! -f "mt5setup.exe" ]; then
    wget -O mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe || {
        echo "⚠️  Direct download failed, trying alternative..."
        # Alternative download source
        wget -O mt5setup.exe "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" || {
            echo "❌ Failed to download MT5 installer"
            echo "   Please download manually from: https://www.metatrader5.com/en/download"
            exit 1
        }
    }
fi

echo ""
echo "📦 Installing MT5 Terminal (this may take a few minutes)..."
echo "   Note: You may see Wine GUI windows - installation is in progress"

# Install MT5 (silent mode if possible)
WINEDLLOVERRIDES="mscoree,mshtml=" wine mt5setup.exe /S 2>/dev/null || {
    echo "⚠️  Silent install failed, trying interactive..."
    WINEDLLOVERRIDES="mscoree,mshtml=" wine mt5setup.exe
}

# Wait for installation
sleep 5

# Check if MT5 was installed
if [ -f "$MT5_DIR/terminal64.exe" ]; then
    echo "✅ MT5 Terminal installed successfully!"
    echo "   Location: $MT5_DIR"
else
    echo "⚠️  MT5 Terminal executable not found in expected location"
    echo "   Checking alternative locations..."
    find ~/.wine -name "terminal64.exe" 2>/dev/null || echo "   Not found"
fi

# Create startup script
echo ""
echo "📝 Creating startup script..."
cat > /opt/start_mt5.sh <<EOF
#!/bin/bash
# Start MT5 Terminal

MT5_DIR="\$HOME/.wine/drive_c/Program Files/MetaTrader 5"

if [ -f "\$MT5_DIR/terminal64.exe" ]; then
    cd "\$MT5_DIR"
    WINEDLLOVERRIDES="mscoree,mshtml=" wine terminal64.exe
else
    echo "❌ MT5 Terminal not found at: \$MT5_DIR"
    echo "   Please install MT5 Terminal first"
    exit 1
fi
EOF

chmod +x /opt/start_mt5.sh

echo "✅ Startup script created: /opt/start_mt5.sh"
echo ""
echo "📋 Next Steps:"
echo "   1. Start MT5 Terminal: /opt/start_mt5.sh"
echo "   2. Log in to your MT5 account in the terminal"
echo "   3. Install/start RPC server EA in MT5"
echo "   4. Test connection: python3 test_mt5_connection_v3.py"
echo ""



