#!/bin/bash
# Setup Wine for headless VPS (no GUI)

set -e

echo "🔧 Setting up Wine for Headless VPS"
echo "==================================="

# Install Xvfb (virtual display) and required packages
echo "📦 Installing Xvfb and display dependencies..."
apt-get update
apt-get install -y xvfb x11vnc xfonts-base xfonts-75dpi xfonts-100dpi

# Install wine32 if not already installed
if ! dpkg -l | grep -q wine32; then
    echo "📦 Installing wine32..."
    dpkg --add-architecture i386
    apt-get update
    apt-get install -y wine32:i386
fi

# Set up Wine environment variables for headless operation
echo ""
echo "🍷 Configuring Wine for headless operation..."

# Create Wine prefix directory
export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
export WINEARCH=win64

# Initialize Wine with virtual display
echo "   Starting virtual display..."
Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
XVFB_PID=$!
sleep 2

# Initialize Wine
echo "   Initializing Wine..."
WINEDLLOVERRIDES="mscoree,mshtml=" DISPLAY=:99 winecfg -v win10 2>/dev/null || {
    echo "   Wine initialization (this is normal on first run)"
}

# Create wrapper script for running Wine apps
cat > /usr/local/bin/wine-headless <<'EOF'
#!/bin/bash
# Wrapper to run Wine applications with virtual display

export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="

# Start Xvfb if not running
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
fi

# Run the command
wine "$@"
EOF

chmod +x /usr/local/bin/wine-headless

# Create systemd service to keep Xvfb running
cat > /etc/systemd/system/xvfb.service <<'EOF'
[Unit]
Description=Virtual Framebuffer X Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1024x768x24
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xvfb
systemctl start xvfb

echo ""
echo "✅ Headless Wine setup complete!"
echo ""
echo "📋 Usage:"
echo "   Use 'wine-headless' instead of 'wine' to run GUI applications"
echo "   Example: wine-headless /path/to/program.exe"
echo ""
echo "📋 Next: Install MT5 Terminal"
echo "   Run: ./INSTALL_MT5_HEADLESS.sh"
echo ""



