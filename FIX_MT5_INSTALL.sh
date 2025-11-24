#!/bin/bash
# Fix MT5 Terminal installation

set -e

echo "🔧 Fixing MT5 Terminal Installation"
echo "==================================="

# Step 1: Install wine32 (required for MT5)
echo "📦 Installing wine32 (32-bit support)..."
dpkg --add-architecture i386
apt-get update
apt-get install -y wine32:i386

echo ""
echo "✅ wine32 installed"
echo ""

# Step 2: Check if MT5 is already installed somewhere
echo "🔍 Searching for MT5 Terminal installation..."
MT5_FOUND=$(find ~/.wine -name "terminal64.exe" -o -name "terminal.exe" 2>/dev/null | head -1)

if [ -n "$MT5_FOUND" ]; then
    echo "✅ Found MT5 Terminal at: $MT5_FOUND"
    MT5_DIR=$(dirname "$MT5_FOUND")
    echo "   Directory: $MT5_DIR"
    
    # Update startup script
    cat > /opt/start_mt5.sh <<EOF
#!/bin/bash
# Start MT5 Terminal

MT5_DIR="$MT5_DIR"

if [ -f "\$MT5_DIR/terminal64.exe" ]; then
    cd "\$MT5_DIR"
    WINEDLLOVERRIDES="mscoree,mshtml=" wine terminal64.exe
elif [ -f "\$MT5_DIR/terminal.exe" ]; then
    cd "\$MT5_DIR"
    WINEDLLOVERRIDES="mscoree,mshtml=" wine terminal.exe
else
    echo "❌ MT5 Terminal executable not found"
    exit 1
fi
EOF
    chmod +x /opt/start_mt5.sh
    echo "✅ Startup script updated"
else
    echo "⚠️  MT5 Terminal not found, will reinstall..."
    
    # Step 3: Reinstall MT5 with proper Wine setup
    echo ""
    echo "📦 Reinstalling MT5 Terminal..."
    
    # Initialize Wine properly
    echo "🍷 Initializing Wine..."
    WINEDLLOVERRIDES="mscoree,mshtml=" winecfg -v win10 2>/dev/null || true
    
    # Download installer if not present
    cd /tmp
    if [ ! -f "mt5setup.exe" ]; then
        echo "📥 Downloading MT5 installer..."
        wget -O mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
    fi
    
    # Install MT5 (interactive - user needs to complete in GUI)
    echo ""
    echo "📦 Installing MT5 Terminal..."
    echo "   ⚠️  IMPORTANT: A Wine GUI window will open."
    echo "   Please complete the installation in the GUI:"
    echo "   1. Click 'Next' through the installer"
    echo "   2. Choose installation directory (default is fine)"
    echo "   3. Complete the installation"
    echo "   4. Wait for installation to finish"
    echo ""
    echo "   Starting installer in 3 seconds..."
    sleep 3
    
    WINEDLLOVERRIDES="mscoree,mshtml=" wine mt5setup.exe
    
    # Wait a bit for installation
    echo ""
    echo "⏳ Waiting for installation to complete..."
    sleep 10
    
    # Check again
    MT5_FOUND=$(find ~/.wine -name "terminal64.exe" -o -name "terminal.exe" 2>/dev/null | head -1)
    
    if [ -n "$MT5_FOUND" ]; then
        echo "✅ MT5 Terminal installed at: $MT5_FOUND"
        MT5_DIR=$(dirname "$MT5_FOUND")
        
        # Update startup script
        cat > /opt/start_mt5.sh <<EOF
#!/bin/bash
# Start MT5 Terminal

MT5_DIR="$MT5_DIR"

if [ -f "\$MT5_DIR/terminal64.exe" ]; then
    cd "\$MT5_DIR"
    WINEDLLOVERRIDES="mscoree,mshtml=" wine terminal64.exe
elif [ -f "\$MT5_DIR/terminal.exe" ]; then
    cd "\$MT5_DIR"
    WINEDLLOVERRIDES="mscoree,mshtml=" wine terminal.exe
else
    echo "❌ MT5 Terminal executable not found"
    exit 1
fi
EOF
        chmod +x /opt/start_mt5.sh
        echo "✅ Startup script created"
    else
        echo "⚠️  MT5 Terminal still not found after installation"
        echo "   Please check if installation completed successfully"
        echo "   You may need to run the installer manually:"
        echo "   wine /tmp/mt5setup.exe"
    fi
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Start MT5 Terminal: /opt/start_mt5.sh"
echo "   2. Log in to your MT5 account"
echo "   3. Install RPC server EA"
echo ""

