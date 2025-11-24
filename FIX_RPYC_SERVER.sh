#!/bin/bash
# Fix RPyC server startup issues

set -e

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "🔧 Fixing RPyC Server"
echo "===================="
echo ""

# Check logs first
echo "📋 Checking RPyC server logs..."
journalctl -u mt5-rpyc -n 20 --no-pager

echo ""
echo "🔍 Diagnosing issue..."

# Check if Windows Python exists
export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99

echo ""
echo "🧪 Testing Windows Python..."
if DISPLAY=:99 wine python --version >/dev/null 2>&1; then
    PYTHON_PATH=$(DISPLAY=:99 wine cmd.exe /c "where python" 2>/dev/null | tr -d '\r' || echo "python.exe")
    echo "✅ Windows Python found"
    echo "   Path: $PYTHON_PATH"
else
    echo "❌ Windows Python not found"
    exit 1
fi

# Try to find Python.exe path
echo ""
echo "🔍 Finding Python.exe path..."
PYTHON_EXE=$(find "$WINEPREFIX" -name "python.exe" 2>/dev/null | head -1)
if [ -n "$PYTHON_EXE" ]; then
    echo "✅ Found Python.exe: $PYTHON_EXE"
    # Convert to Wine path format
    PYTHON_WINE_PATH=$(echo "$PYTHON_EXE" | sed "s|$WINEPREFIX/drive_c|C:|" | sed 's|/|\\|g')
    echo "   Wine path: $PYTHON_WINE_PATH"
else
    echo "⚠️  Python.exe not found, using default"
    PYTHON_WINE_PATH="python.exe"
fi

# Test RPyC server manually
echo ""
echo "🧪 Testing RPyC server manually..."
cd /opt/mt5-api-bridge
source venv/bin/activate

# Stop existing service
systemctl stop mt5-rpyc 2>/dev/null || true

# Try starting manually to see error
echo "   Attempting to start RPyC server..."
timeout 5 python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe 2>&1 | head -20 || {
    echo "   Error captured above"
}

# Fix systemd service
echo ""
echo "🔧 Updating systemd service..."
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

# Try starting again
echo ""
echo "🔄 Starting RPyC server..."
systemctl start mt5-rpyc
sleep 3

if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server started successfully!"
    echo "   Port: $(ss -tlnp | grep :8001 | awk '{print $4}' || echo 'Checking...')"
else
    echo "❌ RPyC server still failing"
    echo ""
    echo "📋 Recent logs:"
    journalctl -u mt5-rpyc -n 30 --no-pager
    echo ""
    echo "💡 Try starting manually to see the error:"
    echo "   cd /opt/mt5-api-bridge"
    echo "   source venv/bin/activate"
    echo "   python3 -m mt5linux --host 0.0.0.0 -p 8001 -w 'DISPLAY=:99 wine' python.exe"
fi

