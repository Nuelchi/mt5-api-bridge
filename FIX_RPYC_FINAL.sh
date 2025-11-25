#!/bin/bash
# Final fix for RPyC server - correct wine command and Python path

set -e

cd /opt/mt5-api-bridge
source venv/bin/activate

export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99

echo "🔧 Final Fix for RPyC Server"
echo "============================"
echo ""

# Find the correct Python.exe path
echo "🔍 Finding Windows Python.exe..."
PYTHON_EXE=$(find "$WINEPREFIX" -name "python.exe" -path "*/Python*/python.exe" 2>/dev/null | grep -v venv | grep -v Lib | head -1)

if [ -z "$PYTHON_EXE" ]; then
    # Try alternative locations
    PYTHON_EXE=$(find "$WINEPREFIX/drive_c" -name "python.exe" 2>/dev/null | grep -E "(Python|python)" | grep -v venv | head -1)
fi

if [ -z "$PYTHON_EXE" ]; then
    echo "❌ Python.exe not found!"
    echo "   Searching all locations..."
    find "$WINEPREFIX" -name "python.exe" 2>/dev/null
    exit 1
fi

echo "✅ Found Python.exe: $PYTHON_EXE"

# Convert to Windows path format for Wine
PYTHON_WINE_PATH=$(echo "$PYTHON_EXE" | sed "s|$WINEPREFIX/drive_c|C:|" | sed 's|/|\\|g')
echo "   Wine path: $PYTHON_WINE_PATH"

# Test if this Python works
echo ""
echo "🧪 Testing Windows Python..."
if DISPLAY=:99 wine "$PYTHON_EXE" --version >/dev/null 2>&1; then
    PYTHON_VERSION=$(DISPLAY=:99 wine "$PYTHON_EXE" --version 2>&1)
    echo "✅ Python works: $PYTHON_VERSION"
else
    echo "⚠️  Python test failed, but continuing..."
fi

# Stop existing service
echo ""
echo "🛑 Stopping existing RPyC server..."
systemctl stop mt5-rpyc 2>/dev/null || true
sleep 2

# Create fixed systemd service
echo "🔧 Creating fixed systemd service..."
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
ExecStart=/opt/mt5-api-bridge/venv/bin/python3 -m mt5linux --host 0.0.0.0 -p 8001 -w wine "$PYTHON_WINE_PATH"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Test manually first
echo ""
echo "🧪 Testing RPyC server manually (5 seconds)..."
timeout 5 python3 -m mt5linux --host 0.0.0.0 -p 8001 -w wine "$PYTHON_WINE_PATH" 2>&1 | head -10 || {
    echo "   Manual test completed (timeout expected)"
}

# Start service
echo ""
echo "🔄 Starting RPyC server service..."
systemctl start mt5-rpyc
sleep 5

# Check status
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server started successfully!"
    echo "   Port: $(ss -tlnp | grep :8001 | awk '{print $4}' || echo '8001')"
    echo ""
    echo "📊 Service status:"
    systemctl status mt5-rpyc --no-pager -l | head -15
else
    echo "❌ RPyC server still failing"
    echo ""
    echo "📋 Recent logs:"
    journalctl -u mt5-rpyc -n 20 --no-pager
    echo ""
    echo "💡 The issue might be:"
    echo "   1. Windows Python path is incorrect"
    echo "   2. MT5 Terminal needs to be running"
    echo "   3. Check: DISPLAY=:99 wine '$PYTHON_EXE' --version"
fi

echo ""
echo "✅ Fix complete!"
echo ""



