#!/bin/bash
# Start MT5 Terminal with proper diagnostics

set -e

export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

echo "🚀 Starting MT5 Terminal"
echo "======================="
echo ""

# Check if MT5 file exists
if [ ! -f "$MT5FILE" ]; then
    echo "❌ MT5 Terminal not found at: $MT5FILE"
    echo ""
    echo "📋 Checking for MT5 installation..."
    find "$WINEPREFIX/drive_c" -name "terminal*.exe" 2>/dev/null | head -5
    exit 1
fi

echo "✅ MT5 Terminal found: $MT5FILE"
echo ""

# Check if already running
if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal is already running"
    pgrep -f "terminal64.exe\|terminal.exe" | while read pid; do
        echo "   PID: $pid"
        ps -p $pid -o lstart=,etime=,cmd=
    done
    exit 0
fi

# Ensure virtual display is running
echo "[1/4] Checking virtual display..."
if ! pgrep -x Xvfb > /dev/null; then
    echo "   Starting Xvfb..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
    echo "✅ Virtual display started"
else
    echo "✅ Virtual display already running"
fi
echo ""

# Check Wine
echo "[2/4] Checking Wine..."
if ! command -v wine > /dev/null; then
    echo "❌ Wine not found"
    exit 1
fi
WINE_VERSION=$(wine --version 2>&1 || echo "unknown")
echo "✅ Wine found: $WINE_VERSION"
echo ""

# Check Wine prefix
echo "[3/4] Checking Wine prefix..."
if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix not found: $WINEPREFIX"
    exit 1
fi
echo "✅ Wine prefix exists: $WINEPREFIX"
echo ""

# Start MT5 Terminal
echo "[4/4] Starting MT5 Terminal..."
echo "   Command: DISPLAY=:99 WINEDLLOVERRIDES=\"mscoree,mshtml=\" wine \"$MT5FILE\""
echo "   This may take 30-60 seconds..."
echo ""

# Start in background but capture output
DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5FILE" > /tmp/mt5_startup.log 2>&1 &
MT5_PID=$!
echo "   MT5 Terminal process started (PID: $MT5_PID)"
echo ""

# Wait and check if process is still running
echo "⏳ Waiting for MT5 Terminal to initialize..."
for i in {1..12}; do
    sleep 5
    if ! kill -0 $MT5_PID 2>/dev/null; then
        echo ""
        echo "❌ MT5 Terminal process died (PID: $MT5_PID)"
        echo ""
        echo "📋 Last 20 lines of startup log:"
        tail -20 /tmp/mt5_startup.log
        echo ""
        echo "📋 Checking for Wine errors..."
        dmesg | tail -10 | grep -i wine || echo "   No Wine errors in dmesg"
        exit 1
    fi
    
    # Check if terminal process is actually running
    if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
        echo "   ✅ MT5 Terminal is running! (after $((i*5))s)"
        break
    fi
    
    echo -n "   Waiting... ($((i*5))s) "
done

echo ""
echo ""

# Final check
if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal is running!"
    echo ""
    echo "📊 Process Information:"
    pgrep -f "terminal64.exe\|terminal.exe" | while read pid; do
        echo "   PID: $pid"
        ps -p $pid -o lstart=,etime=,rss=,vsz=,cmd= | head -1
    done
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Wait 30-60 seconds for MT5 to fully initialize"
    echo "   2. Test connection: python3 -c \"from mt5linux import MetaTrader5; mt5 = MetaTrader5(host='localhost', port=8001); print('Connected!' if mt5.terminal_info() else 'Not ready')\""
    echo "   3. Check RPyC server: systemctl status mt5-rpyc"
else
    echo "⚠️  MT5 Terminal may not have started properly"
    echo ""
    echo "📋 Troubleshooting:"
    echo "   1. Check startup log: tail -50 /tmp/mt5_startup.log"
    echo "   2. Check Wine: wine --version"
    echo "   3. Try starting manually: DISPLAY=:99 wine \"$MT5FILE\""
    echo "   4. Check system resources: free -h && df -h"
fi
echo ""

