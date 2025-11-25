#!/bin/bash
# Continue MT5 setup from where it left off

set -e

echo "🔧 Continuing MT5 Setup"
echo "======================"
echo ""

export WINEPREFIX="$HOME/.wine"
export WINEDEBUG="-all"
export DISPLAY=:99
MT5SERVER_PORT="8001"
PYTHON_VERSION="3.9.13"
METATRADER_VERSION="5.0.36"
MONO_URL="https://dl.winehq.org/wine/wine-mono/10.3.0/wine-mono-10.3.0-x86.msi"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}.exe"
MT5SETUP_URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

# Ensure virtual display is running
if ! pgrep -x Xvfb > /dev/null; then
    echo "🖥️  Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
fi

# Step 1: Check/Install Mono
echo "[1/5] Checking Mono..."
if [ ! -e "$WINEPREFIX/drive_c/windows/mono" ]; then
    echo "   Installing Mono..."
    curl -o /tmp/mono.msi "$MONO_URL"
    DISPLAY=:99 WINEDLLOVERRIDES=mscoree=d wine msiexec /i /tmp/mono.msi /qn >/dev/null 2>&1
    sleep 10
    rm /tmp/mono.msi
    if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
        echo "✅ Mono installed"
    else
        echo "⚠️  Mono installation may have failed, continuing..."
    fi
else
    echo "✅ Mono already installed"
fi

# Step 2: Install MT5 Terminal
echo ""
echo "[2/5] Installing MetaTrader 5..."
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ -e "$MT5FILE" ]; then
    echo "✅ MT5 Terminal already installed"
else
    echo "📥 Downloading MT5 installer..."
    DISPLAY=:99 wine reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f >/dev/null 2>&1 || true
    curl -o /tmp/mt5setup.exe "$MT5SETUP_URL"
    
    echo "📦 Installing MT5 (this may take 5-10 minutes)..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine /tmp/mt5setup.exe /auto >/dev/null 2>&1 || {
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
        echo "⚠️  MT5 installation may have failed. Check manually."
        echo "   Expected location: $MT5FILE"
    fi
fi

# Step 3: Install Windows Python
echo ""
echo "[3/5] Installing Windows Python in Wine..."
if ! DISPLAY=:99 wine python --version >/dev/null 2>&1; then
    echo "📥 Downloading Windows Python ${PYTHON_VERSION}..."
    curl -L "$PYTHON_URL" -o /tmp/python-installer.exe
    
    echo "📦 Installing Python in Wine (this may take 5-10 minutes)..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine /tmp/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1 >/dev/null 2>&1
    sleep 20
    rm /tmp/python-installer.exe
    
    if DISPLAY=:99 wine python --version >/dev/null 2>&1; then
        echo "✅ Windows Python installed: $(DISPLAY=:99 wine python --version 2>&1)"
    else
        echo "❌ Failed to install Windows Python"
        echo "   Searching for Python installation..."
        find "$WINEPREFIX" -name "python.exe" 2>/dev/null | head -1 || echo "   Python not found"
        exit 1
    fi
else
    echo "✅ Windows Python already installed: $(DISPLAY=:99 wine python --version 2>&1)"
fi

# Step 4: Install Windows MetaTrader5 library
echo ""
echo "[4/5] Installing Windows MetaTrader5 library..."
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
echo "[5/5] Installing mt5linux in Windows Python..."
if ! DISPLAY=:99 wine python -c "import mt5linux" >/dev/null 2>&1; then
    DISPLAY=:99 wine python -m pip install --no-cache-dir "mt5linux>=0.1.9" >/dev/null 2>&1
    echo "✅ mt5linux installed in Windows Python"
else
    echo "✅ mt5linux already installed in Windows Python"
fi

# Restart RPyC server
echo ""
echo "🔄 Restarting RPyC server..."
systemctl restart mt5-rpyc 2>/dev/null || {
    echo "   Creating RPyC server service..."
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
}

sleep 3
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server restarted on port $MT5SERVER_PORT"
else
    echo "⚠️  RPyC server may have failed to start. Check: systemctl status mt5-rpyc"
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



