#!/bin/bash
# Fix MT5 Terminal crash issues

set -e

export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

echo "🔧 Fixing MT5 Terminal Crash"
echo "============================"
echo ""

# Step 1: Kill any existing MT5 processes
echo "[1/6] Cleaning up existing MT5 processes..."
pkill -9 -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
sleep 2
echo "✅ Cleaned up"
echo ""

# Step 2: Check Wine configuration
echo "[2/6] Checking Wine configuration..."
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "⚠️  Wine prefix appears corrupted or not initialized"
    echo "   You may need to reinstall MT5 Terminal"
else
    echo "✅ Wine prefix exists"
fi
echo ""

# Step 3: Try different Wine DLL overrides
echo "[3/6] Trying alternative Wine DLL overrides..."
echo "   Attempting with minimal DLL overrides..."

# Try with different DLL overrides
DISPLAY=:99 WINEDLLOVERRIDES="mscoree=" wine "$MT5FILE" > /tmp/mt5_attempt1.log 2>&1 &
PID1=$!
sleep 10

if kill -0 $PID1 2>/dev/null && pgrep -f "terminal64.exe" > /dev/null; then
    echo "✅ MT5 started successfully with minimal DLL overrides!"
    echo "   PID: $PID1"
    exit 0
fi

# Kill if it crashed
kill $PID1 2>/dev/null || true
sleep 2

echo "   First attempt failed, trying with no DLL overrides..."
DISPLAY=:99 WINEDLLOVERRIDES="" wine "$MT5FILE" > /tmp/mt5_attempt2.log 2>&1 &
PID2=$!
sleep 10

if kill -0 $PID2 2>/dev/null && pgrep -f "terminal64.exe" > /dev/null; then
    echo "✅ MT5 started successfully with no DLL overrides!"
    echo "   PID: $PID2"
    exit 0
fi

# Kill if it crashed
kill $PID2 2>/dev/null || true
sleep 2

echo "   Second attempt failed, trying with full DLL overrides..."
DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=n" wine "$MT5FILE" > /tmp/mt5_attempt3.log 2>&1 &
PID3=$!
sleep 10

if kill -0 $PID3 2>/dev/null && pgrep -f "terminal64.exe" > /dev/null; then
    echo "✅ MT5 started successfully with full DLL overrides!"
    echo "   PID: $PID3"
    exit 0
fi

# Kill if it crashed
kill $PID3 2>/dev/null || true
sleep 2

echo "   All attempts failed"
echo ""

# Step 4: Check if we need to reinstall Wine components
echo "[4/6] Checking Wine components..."
if command -v winetricks > /dev/null; then
    echo "✅ winetricks is available"
    echo "   You may need to run: winetricks vcrun2015 vcrun2019"
else
    echo "⚠️  winetricks not installed"
    echo "   Install with: apt-get install winetricks"
fi
echo ""

# Step 5: Try starting in a loop with delays
echo "[5/6] Attempting to start MT5 in a loop (with retries)..."
MAX_RETRIES=3
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    RETRY=$((RETRY + 1))
    echo "   Attempt $RETRY/$MAX_RETRIES..."
    
    # Kill any existing screen session first
    screen -S mt5_terminal -X quit 2>/dev/null || true
    sleep 2
    
    # Try starting with screen to keep it alive
    screen -dmS mt5_terminal bash -c "export DISPLAY=:99 && export WINEPREFIX=\$HOME/.wine && cd /opt/mt5-api-bridge && wine \"\$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\" 2>&1 | tee /tmp/mt5_screen.log"
    
    # Wait longer and check multiple times
    echo "   Waiting 20 seconds and checking if process stays alive..."
    sleep 20
    
    # Check if process is running
    if pgrep -f "terminal64.exe" > /dev/null; then
        # Wait another 10 seconds and check again to ensure it's stable
        sleep 10
        if pgrep -f "terminal64.exe" > /dev/null; then
            echo "✅ MT5 Terminal started successfully in screen session!"
            echo "   Process verified stable after 30 seconds"
            pgrep -f "terminal64.exe" | while read pid; do
                echo "   PID: $pid"
                ps -p $pid -o lstart=,etime= | head -1
            done
            screen -ls | grep mt5_terminal || echo "   (Screen session may have detached)"
            echo ""
            echo "   To view the screen: screen -r mt5_terminal"
            echo "   To detach: Ctrl+A then D"
            exit 0
        else
            echo "   Process started but crashed after 20 seconds"
        fi
    else
        echo "   Process failed to start or crashed immediately"
        if [ -f /tmp/mt5_screen.log ]; then
            echo "   Last 10 lines of screen log:"
            tail -10 /tmp/mt5_screen.log
        fi
    fi
    
    echo "   Attempt $RETRY failed, waiting 5 seconds..."
    sleep 5
done

echo "   All retry attempts failed"
echo ""

# Step 6: Show diagnostic information
echo "[6/6] Diagnostic Information"
echo "==========================="
echo ""

echo "📋 Last error from attempt 1:"
tail -10 /tmp/mt5_attempt1.log 2>/dev/null || echo "   No log available"
echo ""

echo "📋 Last error from attempt 2:"
tail -10 /tmp/mt5_attempt2.log 2>/dev/null || echo "   No log available"
echo ""

echo "📋 Last error from attempt 3:"
tail -10 /tmp/mt5_attempt3.log 2>/dev/null || echo "   No log available"
echo ""

echo "📋 Screen session log (if exists):"
if [ -f /tmp/mt5_screen.log ]; then
    echo "   Last 30 lines:"
    tail -30 /tmp/mt5_screen.log
else
    echo "   No screen log found"
fi
echo ""

echo "📋 System Information:"
echo "   Wine version: $(wine --version 2>&1)"
echo "   Available memory: $(free -h | grep Mem | awk '{print $7}')"
echo "   Disk space: $(df -h / | tail -1 | awk '{print $4}')"
echo ""

echo "❌ Failed to start MT5 Terminal after all attempts"
echo ""
echo "📋 Recommended Next Steps:"
echo "   1. Check if MT5 Terminal file is corrupted:"
echo "      md5sum \"$MT5FILE\""
echo ""
echo "   2. Try reinstalling Wine components:"
echo "      winetricks vcrun2015 vcrun2019 corefonts"
echo ""
echo "   3. Try creating a fresh Wine prefix:"
echo "      export WINEPREFIX=\$HOME/.wine_mt5"
echo "      winecfg"
echo "      # Then reinstall MT5 Terminal"
echo ""
echo "   4. Check Wine logs for more details:"
echo "      tail -100 /tmp/mt5_attempt*.log"
echo ""
echo "   5. Try using a different Wine version (if available)"
echo ""

exit 1
