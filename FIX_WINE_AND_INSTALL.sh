#!/bin/bash
# Fix Wine initialization and install everything properly

set -e

export WINEPREFIX="$HOME/.wine"
export WINEDEBUG="-all"
export DISPLAY=:99

echo "🔧 Fixing Wine and Installing MT5"
echo "=================================="
echo ""

# Step 1: Ensure virtual display is running
echo "[1/6] Setting up virtual display..."
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 3
fi
echo "✅ Virtual display ready"

# Step 2: Fix Wine initialization
echo ""
echo "[2/6] Fixing Wine initialization..."
if [ -d "$WINEPREFIX" ]; then
    echo "   Backing up old Wine prefix..."
    mv "$WINEPREFIX" "${WINEPREFIX}.backup.$(date +%s)" 2>/dev/null || true
fi

echo "   Creating new Wine prefix..."
mkdir -p "$WINEPREFIX"

# Initialize Wine properly
echo "   Running wineboot..."
DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init 2>&1 | head -20 || {
    echo "   wineboot failed, trying winecfg..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" winecfg -v win10 2>&1 | head -20 || true
}

sleep 5

# Test Wine
if DISPLAY=:99 wine --version >/dev/null 2>&1; then
    echo "✅ Wine initialized: $(DISPLAY=:99 wine --version 2>&1)"
else
    echo "❌ Wine initialization failed"
    echo "   Try: apt-get install --reinstall wine wine64"
    exit 1
fi

# Step 3: Install Mono (optional, but recommended)
echo ""
echo "[3/6] Installing Mono (optional, can skip if MT5 works without it)..."
MONO_URL="https://dl.winehq.org/wine/wine-mono/10.3.0/wine-mono-10.3.0-x86.msi"

if [ ! -e "$WINEPREFIX/drive_c/windows/mono" ]; then
    echo "   Downloading Mono..."
    curl -o /tmp/mono.msi "$MONO_URL" 2>&1 | grep -E "%|Total|Speed" || true
    
    echo "   Installing Mono (5-10 minutes)..."
    DISPLAY=:99 WINEDLLOVERRIDES=mscoree=d timeout 600 wine msiexec /i /tmp/mono.msi /qn 2>&1 | tail -5 || {
        echo "   ⚠️  Mono installation timed out or failed, continuing anyway..."
    }
    sleep 5
    rm -f /tmp/mono.msi
    
    if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
        echo "✅ Mono installed"
    else
        echo "⚠️  Mono not installed (MT5 may still work)"
    fi
else
    echo "✅ Mono already installed"
fi

# Step 4: Install MT5 Terminal
echo ""
echo "[4/6] Installing MetaTrader 5..."
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
MT5SETUP_URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

if [ -e "$MT5FILE" ]; then
    echo "✅ MT5 Terminal already installed"
else
    echo "📥 Downloading MT5 installer..."
    curl -o /tmp/mt5setup.exe "$MT5SETUP_URL" 2>&1 | grep -E "%|Total|Speed" || true
    
    echo "📦 Installing MT5 (5-10 minutes)..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f >/dev/null 2>&1 || true
    
    # Try silent install first
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" timeout 600 wine /tmp/mt5setup.exe /auto >/dev/null 2>&1 || {
        echo "   Silent install failed, trying interactive..."
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine /tmp/mt5setup.exe >/dev/null 2>&1 &
        INSTALL_PID=$!
        echo "   Installation started (PID: $INSTALL_PID), waiting 90 seconds..."
        sleep 90
    }
    
    sleep 10
    rm -f /tmp/mt5setup.exe
    
    if [ -e "$MT5FILE" ]; then
        echo "✅ MT5 Terminal installed"
    else
        echo "⚠️  MT5 installation may have failed"
        echo "   Check: ls -la '$MT5FILE'"
    fi
fi

# Step 5: Install Windows Python
echo ""
echo "[5/6] Installing Windows Python..."
PYTHON_VERSION="3.9.13"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}.exe"

if ! DISPLAY=:99 wine python --version >/dev/null 2>&1; then
    echo "📥 Downloading Windows Python ${PYTHON_VERSION}..."
    curl -L "$PYTHON_URL" -o /tmp/python-installer.exe 2>&1 | grep -E "%|Total|Speed" || true
    
    echo "📦 Installing Python (5-10 minutes)..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" timeout 600 wine /tmp/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1 >/dev/null 2>&1
    sleep 20
    rm /tmp/python-installer.exe
    
    if DISPLAY=:99 wine python --version >/dev/null 2>&1; then
        echo "✅ Windows Python installed: $(DISPLAY=:99 wine python --version 2>&1)"
    else
        echo "❌ Failed to install Windows Python"
        exit 1
    fi
else
    echo "✅ Windows Python already installed: $(DISPLAY=:99 wine python --version 2>&1)"
fi

# Step 6: Install Python libraries
echo ""
echo "[6/6] Installing Python libraries..."
METATRADER_VERSION="5.0.36"

# Upgrade pip
DISPLAY=:99 wine python -m pip install --upgrade pip >/dev/null 2>&1

# Install MetaTrader5
if ! DISPLAY=:99 wine python -c "import MetaTrader5" >/dev/null 2>&1; then
    echo "   Installing MetaTrader5==${METATRADER_VERSION}..."
    DISPLAY=:99 wine python -m pip install --no-cache-dir "MetaTrader5==${METATRADER_VERSION}" >/dev/null 2>&1
    echo "✅ MetaTrader5 library installed"
else
    echo "✅ MetaTrader5 library already installed"
fi

# Install mt5linux in Windows Python
if ! DISPLAY=:99 wine python -c "import mt5linux" >/dev/null 2>&1; then
    echo "   Installing mt5linux in Windows Python..."
    DISPLAY=:99 wine python -m pip install --no-cache-dir "mt5linux>=0.1.9" >/dev/null 2>&1
    echo "✅ mt5linux installed in Windows Python"
else
    echo "✅ mt5linux already installed in Windows Python"
fi

# Setup RPyC server
echo ""
echo "🔄 Setting up RPyC server..."
cat > /etc/systemd/system/mt5-rpyc.service <<EOF
[Unit]
Description=MT5 RPyC Server (mt5linux)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mt5-api-bridge
Environment="PATH=/opt/mt5-api-bridge/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="WINEPREFIX=$HOME/.wine"
Environment="DISPLAY=:99"
ExecStart=/opt/mt5-api-bridge/venv/bin/python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-rpyc
systemctl restart mt5-rpyc

sleep 3
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server started on port 8001"
else
    echo "⚠️  RPyC server may have failed. Check: systemctl status mt5-rpyc"
fi

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Start MT5 Terminal: DISPLAY=:99 wine '$MT5FILE' &"
echo "   2. Log in to your MT5 account"
echo "   3. Test connection: python3 test_mt5_connection_v3.py"
echo ""
echo "📊 Check status: ./CHECK_WINE_STATUS.sh"
echo ""

