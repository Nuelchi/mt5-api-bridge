#!/bin/bash
# Fix MT5 Terminal crash issues

set -e

echo "🔧 Fixing MT5 Terminal Crash"
echo "=============================="
echo ""

export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"

# Check log file
echo "[1/7] Checking crash log..."
if [ -f "/tmp/mt5_startup.log" ]; then
    echo "   Last 100 lines of log:"
    echo "   ======================="
    tail -100 /tmp/mt5_startup.log | sed 's/^/   /'
    echo ""
else
    echo "   ⚠️  No log file found"
fi

# Check Mono installation
echo "[2/7] Checking Mono installation..."
MONO_DIR="$WINEPREFIX/drive_c/Program Files/Mono"
if [ -d "$MONO_DIR" ]; then
    echo "✅ Mono is installed: $MONO_DIR"
    ls -la "$MONO_DIR" | head -5
else
    echo "❌ Mono is NOT installed!"
    echo "   Installing Mono..."
    
    # Download and install Mono
    MONO_URL="https://download.mono-project.com/archive/6.12.0/windows-installer/mono-6.12.0.182-x64-0.msi"
    MONO_MSI="/tmp/mono.msi"
    
    echo "   Downloading Mono..."
    wget -q "$MONO_URL" -O "$MONO_MSI" || {
        echo "   ⚠️  Download failed, trying alternative method..."
        # Try installing via Wine's package manager or alternative
        echo "   Please install Mono manually or use the CORRECT_MT5_SETUP.sh script"
    }
    
    if [ -f "$MONO_MSI" ]; then
        echo "   Installing Mono (this may take a few minutes)..."
        DISPLAY=:99 wine msiexec /i "$MONO_MSI" /quiet
        sleep 10
        rm -f "$MONO_MSI"
    fi
fi

echo ""

# Check Wine configuration
echo "[3/7] Checking Wine configuration..."
echo "   Wine version: $(wine --version)"
echo "   Wine prefix: $WINEPREFIX"

# Fix Wine registry for better compatibility
echo "   Updating Wine registry for MT5 compatibility..."
cat > /tmp/mt5_wine_registry.reg <<EOF
REGEDIT4

[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
"mscoree"="native,builtin"
"mshtml"="native,builtin"

[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\terminal64.exe]
"Version"="win10"
EOF

DISPLAY=:99 wine regedit /tmp/mt5_wine_registry.reg 2>/dev/null || echo "   ⚠️  Registry update may have failed (this is usually OK)"
rm -f /tmp/mt5_wine_registry.reg

echo ""

# Check for required DLLs
echo "[4/7] Checking required DLLs..."
REQUIRED_DLLS=("mscoree.dll" "mshtml.dll" "kernel32.dll")
for dll in "${REQUIRED_DLLS[@]}"; do
    if [ -f "$WINEPREFIX/drive_c/windows/system32/$dll" ]; then
        echo "   ✅ $dll found"
    else
        echo "   ⚠️  $dll not found (may cause issues)"
    fi
done

echo ""

# Try to fix Wine prefix
echo "[5/7] Attempting to fix Wine prefix..."
echo "   Running wineboot to refresh Wine prefix..."
DISPLAY=:99 wineboot -u 2>&1 | head -10 || echo "   ⚠️  wineboot had warnings (usually OK)"

echo ""

# Test MT5 with different Wine settings
echo "[6/7] Testing MT5 Terminal with different configurations..."
echo ""

# Configuration 1: Standard
echo "   Test 1: Standard configuration..."
pkill -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
sleep 2

DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" WINEDEBUG=-all wine "$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe" > /tmp/mt5_test1.log 2>&1 &
MT5_PID=$!
sleep 10

if ps -p $MT5_PID > /dev/null 2>&1; then
    echo "   ✅ MT5 Terminal is running with standard config!"
    echo "   PID: $MT5_PID"
    kill $MT5_PID 2>/dev/null || true
    sleep 2
else
    echo "   ❌ MT5 Terminal crashed with standard config"
    echo "   Error log:"
    tail -20 /tmp/mt5_test1.log | sed 's/^/      /'
fi

echo ""

# Configuration 2: With WINEPREFIX explicitly set
echo "   Test 2: With explicit WINEPREFIX..."
pkill -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
sleep 2

env DISPLAY=:99 WINEPREFIX="$HOME/.wine" WINEDLLOVERRIDES="mscoree,mshtml=" WINEDEBUG=-all wine "$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe" > /tmp/mt5_test2.log 2>&1 &
MT5_PID=$!
sleep 10

if ps -p $MT5_PID > /dev/null 2>&1; then
    echo "   ✅ MT5 Terminal is running with explicit WINEPREFIX!"
    echo "   PID: $MT5_PID"
    kill $MT5_PID 2>/dev/null || true
    sleep 2
else
    echo "   ❌ MT5 Terminal crashed with explicit WINEPREFIX"
    echo "   Error log:"
    tail -20 /tmp/mt5_test2.log | sed 's/^/      /'
fi

echo ""

# Create a systemd service for MT5 Terminal
echo "[7/7] Creating MT5 Terminal systemd service..."
echo ""

cat > /etc/systemd/system/mt5-terminal.service <<EOF
[Unit]
Description=MetaTrader 5 Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=root
Environment="DISPLAY=:99"
Environment="WINEPREFIX=$HOME/.wine"
Environment="WINEDLLOVERRIDES=mscoree,mshtml="
Environment="WINEDEBUG=-all"
ExecStart=/usr/bin/wine "$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "✅ MT5 Terminal systemd service created"

echo ""
echo "✅ Fix attempt complete!"
echo ""
echo "📋 Summary:"
echo "   - Mono: $([ -d "$MONO_DIR" ] && echo '✅ Installed' || echo '❌ Not installed')"
echo "   - Wine: ✅ Configured"
echo "   - Systemd service: ✅ Created"
echo ""
echo "💡 Next steps:"
echo "   1. If Mono is missing, run: ./CORRECT_MT5_SETUP.sh (Mono installation section)"
echo "   2. Try starting MT5 via systemd: systemctl start mt5-terminal"
echo "   3. Check status: systemctl status mt5-terminal"
echo "   4. View logs: journalctl -u mt5-terminal -f"
echo ""



