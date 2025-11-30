#!/bin/bash
# Check VNC server and MT5 Terminal status

echo "🔍 Checking VNC and MT5 Status"
echo "=============================="
echo ""

# Step 1: Check VNC server
echo "[1/3] Checking VNC server..."
echo "============================"
VNC_PROCESS=$(pgrep -f "Xvnc\|vncserver\|tigervnc" | head -1)
if [ -n "$VNC_PROCESS" ]; then
    echo "✅ VNC process found (PID: $VNC_PROCESS)"
    ps -p $VNC_PROCESS -o pid=,etime=,cmd= | head -1
else
    echo "❌ VNC server not running"
    echo ""
    echo "💡 To start VNC:"
    echo "   Option 1 (TigerVNC): vncserver :99 -geometry 1024x768 -depth 24"
    echo "   Option 2 (X11VNC): Xvfb :99 -screen 0 1024x768x24 &"
    echo "                     x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared &"
fi
echo ""

# Check VNC port
echo "   Checking VNC port 5900..."
if netstat -tuln 2>/dev/null | grep -q ":5900\|:5999"; then
    echo "   ✅ VNC port is listening"
    netstat -tuln 2>/dev/null | grep ":5900\|:5999"
else
    echo "   ⚠️  VNC port not listening"
fi
echo ""

# Step 2: Check MT5 Terminal
echo "[2/3] Checking MT5 Terminal..."
echo "=============================="
MT5_PIDS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep | awk '{print $2}')
if [ -n "$MT5_PIDS" ]; then
    echo "✅ MT5 Terminal is running"
    for pid in $MT5_PIDS; do
        ps -p $pid -o pid=,etime=,cmd= | head -1
    done
else
    echo "❌ MT5 Terminal is NOT running"
fi
echo ""

# Step 3: Test RPyC connection
echo "[3/3] Testing RPyC connection to MT5..."
echo "======================================"
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   Connecting to RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection established")
    
    print("   Waiting 5 seconds...")
    time.sleep(5)
    
    print("   Attempting to initialize MT5...")
    try:
        initialized = mt5.initialize()
        if initialized:
            print("   ✅ MT5 initialized successfully")
            time.sleep(2)
            
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal info: Build {terminal_info.build}")
                print(f"   ✅ MT5 Terminal is ready for API calls!")
                sys.exit(0)
            else:
                print("   ⚠️  terminal_info() is None")
                print("   MT5 may need more time or a login")
                sys.exit(1)
        else:
            error = mt5.last_error()
            print(f"   ⚠️  Initialize returned False: {error}")
            sys.exit(1)
    except Exception as e:
        error_str = str(e).lower()
        if "timeout" in error_str or "expired" in error_str:
            print(f"   ❌ Timeout: {e}")
            print("   MT5 Terminal is not responding to RPyC calls")
        else:
            print(f"   ❌ Error: {e}")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Connection error: {e}")
    sys.exit(1)
PYEOF

EXIT_CODE=$?
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "=================================="
    echo "✅ MT5 Terminal is ready!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Restart API: sudo systemctl restart mt5-api"
    echo "   2. Connect account via API (see below)"
    echo ""
    echo "   curl -X POST 'https://trade.trainflow.dev/api/v1/accounts/connect' \\"
    echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"account_name\": \"MetaQuotes Demo\", \"login\": \"10008509685\", \"password\": \"!l1cBtTn\", \"server\": \"MetaQuotes-Demo\", \"account_type\": \"demo\", \"set_as_default\": true}'"
else
    echo "=================================="
    echo "⚠️  MT5 Terminal needs more time"
    echo ""
    echo "💡 Wait 2-3 more minutes and run this script again"
fi
echo ""

