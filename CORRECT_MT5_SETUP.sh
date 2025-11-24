#!/bin/bash
# Correct MT5 Setup based on MetaTrader5-Docker approach
# This follows the proven method from mt5-works/MetaTrader5-Docker

set -e

echo "🔧 Correct MT5 Setup for Linux VPS"
echo "=================================="
echo "Based on MetaTrader5-Docker approach"
echo ""

# Configuration
WINEPREFIX="$HOME/.wine"
WINEDEBUG="-all"
MT5SERVER_PORT="8001"
PYTHON_VERSION="3.9.13"
METATRADER_VERSION="5.0.36"
MONO_URL="https://dl.winehq.org/wine/wine-mono/10.3.0/wine-mono-10.3.0-x86.msi"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}.exe"
MT5SETUP_URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

# Check dependencies
echo "📦 Checking dependencies..."
command -v wine >/dev/null 2>&1 || { echo "❌ Wine not installed. Run: apt-get install wine wine64"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 not installed"; exit 1; }

# Set Wine environment
export WINEPREFIX
export WINEDEBUG

# Initialize Wine first (critical step)
echo ""
echo "[0/7] Initializing Wine..."
if [ ! -d "$WINEPREFIX" ]; then
    echo "   Creating Wine prefix..."
    mkdir -p "$WINEPREFIX"
    
    # Set up virtual display for headless operation
    export DISPLAY=:99
    if ! pgrep -x Xvfb > /dev/null; then
        echo "   Starting virtual display (Xvfb)..."
        Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
        sleep 2
    fi
    
    # Initialize Wine
    echo "   Running winecfg to initialize Wine..."
    WINEDLLOVERRIDES="mscoree,mshtml=" winecfg -v win10 >/dev/null 2>&1 || {
        echo "   Wine initialization (this may take a moment)..."
        sleep 3
    }
    echo "✅ Wine initialized"
else
    echo "✅ Wine prefix already exists"
    # Ensure virtual display is running
    export DISPLAY=:99
    if ! pgrep -x Xvfb > /dev/null; then
        Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
        sleep 2
    fi
fi

# Step 1: Install Mono for Wine
echo ""
echo "[1/7] Installing Mono for Wine..."
if [ ! -e "$WINEPREFIX/drive_c/windows/mono" ]; then
    echo "   Downloading Mono..."
    curl -o /tmp/mono.msi "$MONO_URL"
    echo "   Installing Mono (this may take a few minutes)..."
    WINEDLLOVERRIDES=mscoree=d DISPLAY=:99 wine msiexec /i /tmp/mono.msi /qn >/dev/null 2>&1
    sleep 5
    rm /tmp/mono.msi
    if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
        echo "✅ Mono installed"
    else
        echo "⚠️  Mono installation may have failed, continuing anyway..."
    fi
else
    echo "✅ Mono already installed"
fi

# Step 2: Install MT5 Terminal
echo ""
echo "[2/7] Installing MetaTrader 5..."
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ -e "$MT5FILE" ]; then
    echo "✅ MT5 Terminal already installed"
else
    echo "📥 Downloading MT5 installer..."
    DISPLAY=:99 wine reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f >/dev/null 2>&1 || true
    curl -o /tmp/mt5setup.exe "$MT5SETUP_URL"
    
    echo "📦 Installing MT5 (this may take a few minutes)..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine /tmp/mt5setup.exe /auto >/dev/null 2>&1 || {
        echo "   Silent install failed, trying interactive..."
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine /tmp/mt5setup.exe >/dev/null 2>&1 &
        INSTALL_PID=$!
        sleep 60  # Wait for installation
    }
    sleep 10
    rm -f /tmp/mt5setup.exe
    
    if [ -e "$MT5FILE" ]; then
        echo "✅ MT5 Terminal installed"
    else
        echo "⚠️  MT5 installation may have failed. Check manually."
    fi
fi

# Step 3: Install Windows Python in Wine
echo ""
echo "[3/7] Installing Windows Python in Wine..."
if ! DISPLAY=:99 wine python --version >/dev/null 2>&1; then
    echo "📥 Downloading Windows Python ${PYTHON_VERSION}..."
    curl -L "$PYTHON_URL" -o /tmp/python-installer.exe
    
    echo "📦 Installing Python in Wine (this may take a few minutes)..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine /tmp/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1 >/dev/null 2>&1
    sleep 15
    rm /tmp/python-installer.exe
    
    if DISPLAY=:99 wine python --version >/dev/null 2>&1; then
        echo "✅ Windows Python installed: $(DISPLAY=:99 wine python --version 2>&1)"
    else
        echo "❌ Failed to install Windows Python"
        echo "   Trying to find Python installation..."
        find "$WINEPREFIX" -name "python.exe" 2>/dev/null | head -1 || echo "   Python not found"
        exit 1
    fi
else
    echo "✅ Windows Python already installed: $(DISPLAY=:99 wine python --version 2>&1)"
fi

# Step 4: Install Windows MetaTrader5 library
echo ""
echo "[4/7] Installing Windows MetaTrader5 library..."
DISPLAY=:99 wine python -m pip install --upgrade pip >/dev/null 2>&1

if ! DISPLAY=:99 wine python -c "import MetaTrader5" >/dev/null 2>&1; then
    echo "📦 Installing MetaTrader5==${METATRADER_VERSION} in Windows Python..."
    DISPLAY=:99 wine python -m pip install --no-cache-dir "MetaTrader5==${METATRADER_VERSION}" >/dev/null 2>&1
    echo "✅ MetaTrader5 library installed"
else
    echo "✅ MetaTrader5 library already installed"
fi

# Step 5: Install mt5linux in Windows Python
echo ""
echo "[5/7] Installing mt5linux in Windows Python..."
if ! DISPLAY=:99 wine python -c "import mt5linux" >/dev/null 2>&1; then
    DISPLAY=:99 wine python -m pip install --no-cache-dir "mt5linux>=0.1.9" >/dev/null 2>&1
    echo "✅ mt5linux installed in Windows Python"
else
    echo "✅ mt5linux already installed in Windows Python"
fi

# Step 6: Install mt5linux in Linux Python
echo ""
echo "[6/7] Installing mt5linux in Linux Python..."
cd /opt/mt5-api-bridge
source venv/bin/activate

if ! python3 -c "import mt5linux" >/dev/null 2>&1; then
    pip install --no-cache-dir --no-deps mt5linux >/dev/null 2>&1
    pip install --no-cache-dir rpyc plumbum numpy >/dev/null 2>&1
    echo "✅ mt5linux installed in Linux Python"
else
    echo "✅ mt5linux already installed in Linux Python"
fi

# Step 7: Create systemd service for RPyC server
echo ""
echo "[7/7] Creating systemd service for RPyC server..."
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
ExecStart=/opt/mt5-api-bridge/venv/bin/python3 -m mt5linux --host 0.0.0.0 -p $MT5SERVER_PORT -w "DISPLAY=:99 wine" python.exe
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-rpyc
systemctl start mt5-rpyc

sleep 3
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server started on port $MT5SERVER_PORT"
else
    echo "⚠️  RPyC server may have failed to start. Check: systemctl status mt5-rpyc"
fi

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Start MT5 Terminal: wine '$MT5FILE' &"
echo "   2. Log in to your MT5 account in the terminal"
echo "   3. Test connection: python3 test_mt5_connection_v3.py"
echo "   4. The RPyC server is running on port $MT5SERVER_PORT"
echo ""
echo "📊 Service Status:"
echo "   RPyC Server: systemctl status mt5-rpyc"
echo "   View logs: journalctl -u mt5-rpyc -f"
echo ""

