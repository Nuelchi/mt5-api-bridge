#!/bin/bash
# Check Wine and MT5 setup status

echo "🔍 Checking Wine and MT5 Setup Status"
echo "====================================="
echo ""

export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99

# Check Wine
echo "🍷 Wine Status:"
if command -v wine >/dev/null 2>&1; then
    echo "   ✅ Wine installed: $(wine --version)"
else
    echo "   ❌ Wine not installed"
fi

# Check Wine prefix
echo ""
echo "📁 Wine Prefix:"
if [ -d "$WINEPREFIX" ]; then
    echo "   ✅ Wine prefix exists: $WINEPREFIX"
    if [ -d "$WINEPREFIX/drive_c" ]; then
        echo "   ✅ C: drive exists"
    else
        echo "   ⚠️  C: drive not found (Wine may not be initialized)"
    fi
else
    echo "   ❌ Wine prefix not found"
fi

# Check virtual display
echo ""
echo "🖥️  Virtual Display:"
if pgrep -x Xvfb > /dev/null; then
    echo "   ✅ Xvfb is running (PID: $(pgrep -x Xvfb))"
else
    echo "   ⚠️  Xvfb not running"
fi

# Test Wine
echo ""
echo "🧪 Testing Wine:"
if DISPLAY=:99 wine --version >/dev/null 2>&1; then
    WINE_VERSION=$(DISPLAY=:99 wine --version 2>&1)
    echo "   ✅ Wine works: $WINE_VERSION"
else
    echo "   ❌ Wine test failed"
fi

# Check Mono
echo ""
echo "📦 Mono (for Wine):"
if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
    echo "   ✅ Mono installed"
else
    echo "   ⚠️  Mono not installed"
fi

# Check MT5 Terminal
echo ""
echo "📊 MetaTrader 5 Terminal:"
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
if [ -e "$MT5FILE" ]; then
    echo "   ✅ MT5 Terminal installed: $MT5FILE"
else
    echo "   ⚠️  MT5 Terminal not installed"
fi

# Check Windows Python
echo ""
echo "🐍 Windows Python (in Wine):"
if DISPLAY=:99 wine python --version >/dev/null 2>&1; then
    PYTHON_VERSION=$(DISPLAY=:99 wine python --version 2>&1)
    echo "   ✅ Windows Python installed: $PYTHON_VERSION"
    
    # Check MetaTrader5 library
    if DISPLAY=:99 wine python -c "import MetaTrader5" >/dev/null 2>&1; then
        echo "   ✅ MetaTrader5 library installed"
    else
        echo "   ⚠️  MetaTrader5 library not installed"
    fi
    
    # Check mt5linux in Windows Python
    if DISPLAY=:99 wine python -c "import mt5linux" >/dev/null 2>&1; then
        echo "   ✅ mt5linux installed in Windows Python"
    else
        echo "   ⚠️  mt5linux not installed in Windows Python"
    fi
else
    echo "   ⚠️  Windows Python not installed"
fi

# Check Linux Python mt5linux
echo ""
echo "🐍 Linux Python mt5linux:"
if python3 -c "import mt5linux" >/dev/null 2>&1; then
    echo "   ✅ mt5linux installed in Linux Python"
else
    echo "   ⚠️  mt5linux not installed in Linux Python"
fi

# Check RPyC server
echo ""
echo "🔌 RPyC Server:"
if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
    echo "   ✅ RPyC server is running (systemd service)"
    echo "   Port: $(ss -tlnp | grep :8001 | awk '{print $4}' || echo 'Not listening')"
elif ss -tlnp | grep -q ":8001"; then
    echo "   ✅ RPyC server is running (port 8001)"
else
    echo "   ⚠️  RPyC server not running"
fi

echo ""
echo "✅ Status check complete!"
echo ""

