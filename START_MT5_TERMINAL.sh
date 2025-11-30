#!/bin/bash
# Start MT5 Terminal in headless mode with proper setup

MT5_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5"

# Check if MT5 is installed
if [ ! -f "$MT5_DIR/terminal64.exe" ]; then
    echo "❌ MT5 Terminal not found at: $MT5_DIR"
    echo "   Please install MT5 Terminal first: sudo ./INSTALL_MT5_TERMINAL.sh"
    exit 1
fi

# Ensure virtual display is running
if ! pgrep -x Xvfb > /dev/null; then
    echo "   Starting virtual display (Xvfb)..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
    echo "   ✅ Virtual display started"
fi

export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="

# Check if MT5 is already running
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "⚠️  MT5 Terminal is already running"
    echo "   PID: $(pgrep -f terminal64.exe)"
    echo "   To restart, first stop it: pkill -f terminal64.exe"
    exit 0
fi

# Clean up old screen sessions
screen -wipe >/dev/null 2>&1 || true
screen -S mt5_terminal -X quit 2>/dev/null || true
sleep 2

echo "🚀 Starting MT5 Terminal..."
echo "   Using virtual display: DISPLAY=:99"
echo "   Logs: /tmp/mt5_screen.log"

# Start MT5 in screen session (non-blocking)
cd "$MT5_DIR"
screen -dmS mt5_terminal bash -c "export DISPLAY=:99 && export WINEPREFIX=\$HOME/.wine && export WINEDLLOVERRIDES='mscoree,mshtml=' && cd \"$MT5_DIR\" && wine terminal64.exe > /tmp/mt5_screen.log 2>&1"

sleep 10

# Check if it started
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "✅ MT5 Terminal started successfully!"
    echo ""
    echo "📋 Useful commands:"
    echo "   View logs: tail -f /tmp/mt5_screen.log"
    echo "   View screen: screen -r mt5_terminal"
    echo "   Check process: pgrep -f terminal64.exe"
    echo "   Stop MT5: pkill -f terminal64.exe"
else
    echo "⚠️  MT5 Terminal may still be starting..."
    echo "   Check logs: tail -50 /tmp/mt5_screen.log"
    echo "   Wait 30-60 seconds and check again: pgrep -f terminal64.exe"
    echo ""
    echo "   If it fails, try accessing via VNC to see the GUI:"
    echo "   http://147.182.206.223:3000/vnc.html"
fi
