#!/bin/bash
# Fix MT5 Terminal not running issue

set -e

echo "🔧 Fixing MT5 Terminal Connection"
echo "=================================="
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Check if Docker container is running
echo "[1/5] Checking Docker MT5 Container..."
echo "======================================"
DOCKER_CONTAINER=$(docker ps --filter "publish=8001" --format "{{.Names}}" | head -1)
if [ -n "$DOCKER_CONTAINER" ]; then
    echo "✅ Found Docker container using port 8001: $DOCKER_CONTAINER"
    echo "   This might be the MT5 Docker container"
    docker ps --filter "publish=8001" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "   Checking if MT5 Terminal is accessible inside container..."
    docker exec $DOCKER_CONTAINER ps aux | grep -i "terminal\|mt5" | grep -v grep || echo "   ⚠️  No MT5 process found in container"
else
    echo "❌ No Docker container found on port 8001"
fi
echo ""

# Check if native MT5 Terminal process exists
echo "[2/5] Checking Native MT5 Terminal..."
echo "======================================"
MT5_PID=$(pgrep -f "terminal64.exe\|terminal.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "✅ MT5 Terminal process found: PID $MT5_PID"
    ps aux | grep $MT5_PID | grep -v grep
else
    echo "❌ No MT5 Terminal process found"
    echo ""
    echo "   Starting MT5 Terminal..."
    
    # Ensure Xvfb is running
    if ! pgrep -x Xvfb > /dev/null; then
        echo "   Starting Xvfb..."
        Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
        sleep 2
    fi
    
    # Start MT5 Terminal
    export DISPLAY=:99
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    
    if [ -f "$MT5_EXE" ]; then
        echo "   Starting MT5 Terminal: $MT5_EXE"
        DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" >/dev/null 2>&1 &
        sleep 15
        
        MT5_PID=$(pgrep -f "terminal64.exe\|terminal.exe" | head -1)
        if [ -n "$MT5_PID" ]; then
            echo "   ✅ MT5 Terminal started: PID $MT5_PID"
        else
            echo "   ❌ Failed to start MT5 Terminal"
            echo "   Check Wine logs or try starting manually"
        fi
    else
        echo "   ❌ MT5 Terminal executable not found: $MT5_EXE"
        echo "   MT5 Terminal may not be installed"
    fi
fi
echo ""

# Check RPyC server
echo "[3/5] Checking RPyC Server..."
echo "============================="
if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
    echo "✅ RPyC service is running"
else
    echo "⚠️  RPyC service is not running"
    
    # Check if port 8001 is in use by Docker
    if ss -tlnp | grep -q ":8001.*docker-proxy"; then
        echo "   Port 8001 is used by Docker container"
        echo "   If using Docker MT5, RPyC should connect to container"
        echo "   Skipping native RPyC server start"
    else
        echo "   Starting RPyC server..."
        systemctl start mt5-rpyc
        sleep 5
        
        if systemctl is-active --quiet mt5-rpyc; then
            echo "   ✅ RPyC server started"
        else
            echo "   ❌ Failed to start RPyC server"
            echo "   Check logs: journalctl -u mt5-rpyc -n 20"
        fi
    fi
fi
echo ""

# Wait for MT5 to be ready
echo "[4/5] Waiting for MT5 Terminal to be ready..."
echo "==========================================="
if [ -n "$MT5_PID" ] || [ -n "$DOCKER_CONTAINER" ]; then
    echo "   Waiting 30 seconds for MT5 Terminal to fully initialize..."
    sleep 30
    
    # Test connection
    echo "   Testing MT5 connection..."
    python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

max_attempts = 10
attempt = 0

while attempt < max_attempts:
    attempt += 1
    try:
        print(f"   Attempt {attempt}/{max_attempts}...")
        mt5 = MetaTrader5(host='localhost', port=8001)
        
        if mt5.initialize():
            print("   ✅ MT5 initialize() succeeded!")
            
            # Try to get terminal info
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal: {terminal_info.name}")
            
            # Check if logged in
            account_info = mt5.account_info()
            if account_info:
                print(f"   ✅ Account logged in: {account_info.login}")
            else:
                print("   ⚠️  Terminal is running but not logged in")
            
            sys.exit(0)
        else:
            error = mt5.last_error() if hasattr(mt5, 'last_error') else "Unknown"
            print(f"   ⚠️  Initialize failed: {error}")
    except Exception as e:
        if "result expired" in str(e) or "timeout" in str(e).lower():
            print(f"   ⚠️  Timeout (attempt {attempt}/{max_attempts})")
            if attempt < max_attempts:
                time.sleep(5)
                continue
        else:
            print(f"   ❌ Error: {e}")
            sys.exit(1)

print("   ❌ Failed to connect after multiple attempts")
sys.exit(1)
PYEOF

    CONNECTION_TEST=$?
    if [ $CONNECTION_TEST -eq 0 ]; then
        echo "   ✅ MT5 connection successful!"
    else
        echo "   ❌ MT5 connection failed"
    fi
else
    echo "   ⚠️  Cannot test - MT5 Terminal not running"
fi
echo ""

# Summary and next steps
echo "[5/5] Summary and Next Steps"
echo "============================"
if [ -n "$MT5_PID" ] || [ -n "$DOCKER_CONTAINER" ]; then
    echo "✅ MT5 Terminal should be running"
    echo ""
    echo "💡 If connection still fails:"
    echo "   1. Check if MT5 Terminal is fully loaded (may take 1-2 minutes)"
    echo "   2. Try logging in manually via VNC (if available)"
    echo "   3. Check RPyC server logs: journalctl -u mt5-rpyc -n 50"
    echo "   4. Check MT5 Terminal logs in Wine prefix"
else
    echo "❌ MT5 Terminal is still not running"
    echo ""
    echo "💡 Try:"
    echo "   1. Check Wine installation: wine --version"
    echo "   2. Check MT5 installation path"
    echo "   3. Try starting manually:"
    echo "      export DISPLAY=:99"
    echo "      wine \"\$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\""
    echo "   4. Check for errors in Wine logs"
fi
echo ""

