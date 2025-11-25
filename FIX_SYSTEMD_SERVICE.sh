#!/bin/bash
# Fix MT5 Terminal systemd service to work without xvfb.service

set -e

echo "🔧 Fixing MT5 Terminal systemd service"
echo "======================================"
echo ""

# Create Xvfb service first (if it doesn't exist)
if [ ! -f "/etc/systemd/system/xvfb.service" ]; then
    echo "[1/3] Creating Xvfb systemd service..."
    cat > /etc/systemd/system/xvfb.service <<EOF
[Unit]
Description=Virtual Framebuffer X Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xvfb
    systemctl start xvfb
    echo "✅ Xvfb service created and started"
else
    echo "✅ Xvfb service already exists"
    if ! systemctl is-active --quiet xvfb; then
        systemctl start xvfb
        echo "✅ Xvfb service started"
    else
        echo "✅ Xvfb service is already running"
    fi
fi

echo ""

# Fix MT5 Terminal service
echo "[2/3] Updating MT5 Terminal systemd service..."
cat > /etc/systemd/system/mt5-terminal.service <<EOF
[Unit]
Description=MetaTrader 5 Terminal
After=network.target xvfb.service
Wants=xvfb.service

[Service]
Type=simple
User=root
Environment="DISPLAY=:99"
Environment="WINEPREFIX=$HOME/.wine"
Environment="WINEDLLOVERRIDES=mscoree,mshtml="
Environment="WINEDEBUG=-all"
ExecStart=/usr/bin/wine "$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "✅ MT5 Terminal service updated"

echo ""

# Test starting the service
echo "[3/3] Testing MT5 Terminal service..."
echo ""

# Stop any existing MT5 processes
pkill -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
sleep 2

# Start the service
echo "Starting MT5 Terminal service..."
systemctl start mt5-terminal
sleep 10

# Check status
if systemctl is-active --quiet mt5-terminal; then
    echo "✅ MT5 Terminal service is running!"
    echo ""
    echo "   Status:"
    systemctl status mt5-terminal --no-pager -l | head -20
    echo ""
    echo "   Process check:"
    ps aux | grep "terminal64.exe\|terminal.exe" | grep -v grep || echo "   ⚠️  No MT5 process found"
else
    echo "❌ MT5 Terminal service failed to start"
    echo ""
    echo "   Status:"
    systemctl status mt5-terminal --no-pager -l | head -30
    echo ""
    echo "   Recent logs:"
    journalctl -u mt5-terminal -n 30 --no-pager | tail -20
fi

echo ""
echo "✅ Service fix complete!"
echo ""
echo "💡 Commands:"
echo "   Check status: systemctl status mt5-terminal"
echo "   View logs: journalctl -u mt5-terminal -f"
echo "   Restart: systemctl restart mt5-terminal"
echo ""



