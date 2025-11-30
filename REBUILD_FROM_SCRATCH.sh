#!/bin/bash
# Rebuild MT5 API Bridge from scratch
# This will clean up and reinstall everything including VNC

set -e

echo "🔄 Rebuilding MT5 API Bridge from Scratch"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will stop all services and clean up MT5 Terminal"
echo "   Press Ctrl+C within 5 seconds to cancel..."
sleep 5
echo ""

# Step 1: Stop all services
echo "[1/8] Stopping all services..."
echo "==============================="
systemctl stop mt5-api 2>/dev/null || true
systemctl stop mt5-rpyc 2>/dev/null || true
pkill -9 -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
pkill -9 -f "mt5linux\|rpyc" 2>/dev/null || true
screen -wipe >/dev/null 2>&1 || true
screen -S mt5_terminal -X quit 2>/dev/null || true
sleep 3
echo "✅ All services stopped"
echo ""

# Step 2: Clean up MT5 Terminal processes and screen sessions
echo "[2/8] Cleaning up MT5 Terminal processes..."
echo "==========================================="
pkill -9 -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
pkill -9 -f "Xvfb\|vnc" 2>/dev/null || true
screen -wipe >/dev/null 2>&1 || true
sleep 2
echo "✅ Cleanup complete"
echo ""

# Step 3: Clean up Wine/MT5 Terminal (optional - comment out if you want to keep MT5 installation)
echo "[3/8] Cleaning up MT5 Terminal installation..."
echo "=============================================="
read -p "   Do you want to remove MT5 Terminal installation? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   Removing MT5 Terminal..."
    rm -rf "$HOME/.wine/drive_c/Program Files/MetaTrader 5" 2>/dev/null || true
    echo "   ✅ MT5 Terminal removed"
    echo "   ⚠️  You will need to reinstall MT5 Terminal manually"
else
    echo "   ✅ Keeping MT5 Terminal installation"
fi
echo ""

# Step 4: Reinstall system dependencies
echo "[4/8] Installing/updating system dependencies..."
echo "==============================================="
apt-get update -qq
apt-get install -y \
    wine \
    wine64 \
    winetricks \
    xvfb \
    x11vnc \
    tigervnc-standalone-server \
    tigervnc-common \
    screen \
    python3-pip \
    python3-venv \
    || echo "⚠️  Some packages may already be installed"
echo "✅ Dependencies installed"
echo ""

# Step 5: Setup virtual display and VNC
echo "[5/8] Setting up virtual display and VNC..."
echo "==========================================="

# Kill existing Xvfb
pkill -9 Xvfb 2>/dev/null || true
sleep 2

# Start Xvfb
echo "   Starting Xvfb (virtual display)..."
Xvfb :99 -screen 0 1024x768x24 > /tmp/xvfb.log 2>&1 &
sleep 3
if pgrep -x Xvfb > /dev/null; then
    echo "   ✅ Xvfb started"
else
    echo "   ❌ Failed to start Xvfb"
    exit 1
fi

# Setup VNC password (optional - for security)
echo "   Setting up VNC server..."
export DISPLAY=:99

# Start x11vnc to share the Xvfb display
pkill -9 x11vnc 2>/dev/null || true
sleep 2

# Start x11vnc (no password for now - you can add -passwd later)
x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared -rfbport 5900 > /tmp/x11vnc.log 2>&1 &
sleep 3

if pgrep -x x11vnc > /dev/null; then
    echo "   ✅ x11vnc started on port 5900"
    echo "   📡 VNC accessible at: YOUR_SERVER_IP:5900"
else
    echo "   ⚠️  x11vnc failed to start (check /tmp/x11vnc.log)"
    echo "   Continuing anyway..."
fi

# Also try TigerVNC as alternative
if command -v vncserver > /dev/null; then
    echo "   Setting up TigerVNC as alternative..."
    vncserver -kill :1 2>/dev/null || true
    vncserver :1 -geometry 1024x768 -depth 24 -localhost no > /tmp/tigervnc.log 2>&1 || true
    if pgrep -f "vncserver.*:1" > /dev/null; then
        echo "   ✅ TigerVNC started on :1 (port 5901)"
    fi
fi

echo "✅ Virtual display and VNC setup complete"
echo ""

# Step 6: Setup Python environment
echo "[6/8] Setting up Python environment..."
echo "======================================"
cd /opt/mt5-api-bridge

if [ ! -d "venv" ]; then
    echo "   Creating virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate
echo "   Installing Python dependencies..."
pip install --upgrade pip -q
pip install -r requirements.txt -q || {
    echo "   ⚠️  requirements.txt not found, installing basic dependencies..."
    pip install fastapi uvicorn supabase httpx mt5linux rpyc -q
}
echo "✅ Python environment ready"
echo ""

# Step 7: Reinstall MT5 Terminal (if removed)
echo "[7/8] Checking MT5 Terminal installation..."
echo "=========================================="
MT5FILE="$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ ! -f "$MT5FILE" ]; then
    echo "   ⚠️  MT5 Terminal not found at: $MT5FILE"
    echo ""
    echo "   📥 To install MT5 Terminal:"
    echo "      1. Download MT5 installer: wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
    echo "      2. Install: wine mt5setup.exe"
    echo "      3. Or use your existing installation method"
    echo ""
    echo "   For now, continuing without MT5 Terminal..."
    echo "   You can install it later and restart services"
else
    echo "   ✅ MT5 Terminal found"
fi
echo ""

# Step 8: Start services
echo "[8/8] Starting services..."
echo "========================="

# Start RPyC server
echo "   Starting RPyC server..."
systemctl start mt5-rpyc
sleep 5
if systemctl is-active --quiet mt5-rpyc; then
    echo "   ✅ RPyC server started"
else
    echo "   ❌ Failed to start RPyC server"
    echo "   Check: journalctl -u mt5-rpyc -n 50"
fi

# Start MT5 Terminal (if installed)
if [ -f "$MT5FILE" ]; then
    echo "   Starting MT5 Terminal..."
    export WINEPREFIX="$HOME/.wine"
    export DISPLAY=:99
    
    # Clean up old screen sessions
    screen -wipe >/dev/null 2>&1 || true
    screen -S mt5_terminal -X quit 2>/dev/null || true
    sleep 2
    
    # Start MT5 in screen
    screen -dmS mt5_terminal bash -c "export DISPLAY=:99 && export WINEPREFIX=\$HOME/.wine && cd /opt/mt5-api-bridge && wine \"\$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\" 2>&1 | tee /tmp/mt5_screen.log"
    
    echo "   Waiting 60 seconds for MT5 Terminal to start..."
    sleep 60
    
    if pgrep -f "terminal64.exe" > /dev/null; then
        echo "   ✅ MT5 Terminal started"
    else
        echo "   ⚠️  MT5 Terminal may have failed to start"
        echo "   Check: tail -50 /tmp/mt5_screen.log"
    fi
else
    echo "   ⚠️  Skipping MT5 Terminal (not installed)"
fi

# Start API
echo "   Starting API server..."
systemctl start mt5-api
sleep 5
if systemctl is-active --quiet mt5-api; then
    echo "   ✅ API server started"
else
    echo "   ❌ Failed to start API server"
    echo "   Check: journalctl -u mt5-api -n 50"
fi

echo ""
echo "=================================="
echo "✅ Rebuild Complete!"
echo ""
echo "📋 Service Status:"
echo "   RPyC: $(systemctl is-active mt5-rpyc 2>/dev/null || echo 'not running')"
echo "   API: $(systemctl is-active mt5-api 2>/dev/null || echo 'not running')"
echo "   MT5 Terminal: $(pgrep -f 'terminal64.exe' > /dev/null && echo 'running' || echo 'not running')"
echo "   Xvfb: $(pgrep -x Xvfb > /dev/null && echo 'running' || echo 'not running')"
echo "   VNC: $(pgrep -x x11vnc > /dev/null && echo 'running on port 5900' || echo 'not running')"
echo ""
echo "🌐 VNC Access:"
echo "   - x11vnc: YOUR_SERVER_IP:5900 (if running)"
echo "   - TigerVNC: YOUR_SERVER_IP:5901 (if running)"
echo ""
echo "📋 Next Steps:"
echo "   1. Wait 2-3 minutes for MT5 Terminal to fully initialize"
echo "   2. Test VNC connection: vncviewer YOUR_SERVER_IP:5900"
echo "   3. Test API: curl http://localhost:8000/health"
echo "   4. Connect account: curl -X POST 'https://trade.trainflow.dev/api/v1/accounts/connect' ..."
echo ""
echo "📝 Logs:"
echo "   MT5 Terminal: tail -f /tmp/mt5_screen.log"
echo "   RPyC: journalctl -u mt5-rpyc -f"
echo "   API: journalctl -u mt5-api -f"
echo "   VNC: tail -f /tmp/x11vnc.log"
echo ""

