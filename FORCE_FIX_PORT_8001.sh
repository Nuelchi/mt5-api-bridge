#!/bin/bash
# Force fix port 8001 conflict

echo "🔧 Force Fixing Port 8001 Conflict"
echo "==================================="
echo ""

# Step 1: Stop all Docker containers using port 8001
echo "[1/5] Stopping Docker containers..."
docker ps --format "{{.ID}} {{.Names}} {{.Ports}}" | grep "8001" | while read line; do
    CONTAINER_ID=$(echo $line | awk '{print $1}')
    CONTAINER_NAME=$(echo $line | awk '{print $2}')
    echo "   Stopping container: $CONTAINER_NAME ($CONTAINER_ID)"
    docker stop $CONTAINER_ID 2>/dev/null || docker kill $CONTAINER_ID 2>/dev/null || true
done
sleep 3

# Also try to stop by name
docker stop mt5 2>/dev/null || true
docker kill mt5 2>/dev/null || true
sleep 2
echo "✅ Docker containers stopped"
echo ""

# Step 2: Kill all processes using port 8001
echo "[2/5] Killing processes using port 8001..."
PORT_PIDS=$(ss -tlnp | grep ":8001" | grep -oP 'pid=\K[0-9]+' | sort -u)
if [ -n "$PORT_PIDS" ]; then
    for pid in $PORT_PIDS; do
        echo "   Killing process PID: $pid"
        kill -9 $pid 2>/dev/null || true
    done
    sleep 2
else
    echo "   No processes found using port 8001"
fi
echo ""

# Step 3: Kill wineserver64 if it's using port 8001
echo "[3/5] Checking wineserver64..."
WINESERVER_PID=$(ss -tlnp | grep ":8001" | grep "wineserver64" | grep -oP 'pid=\K[0-9]+' | head -1)
if [ -n "$WINESERVER_PID" ]; then
    echo "   Killing wineserver64 (PID: $WINESERVER_PID)"
    kill -9 $WINESERVER_PID 2>/dev/null || true
    sleep 2
else
    echo "   wineserver64 not using port 8001"
fi
echo ""

# Step 4: Verify port 8001 is free
echo "[4/5] Verifying port 8001 is free..."
sleep 3
if ss -tlnp | grep -q ":8001"; then
    echo "   ⚠️  Port 8001 still in use:"
    ss -tlnp | grep ":8001"
    echo "   Trying one more time to kill processes..."
    PORT_PIDS=$(ss -tlnp | grep ":8001" | grep -oP 'pid=\K[0-9]+' | sort -u)
    for pid in $PORT_PIDS; do
        kill -9 $pid 2>/dev/null || true
    done
    sleep 3
else
    echo "✅ Port 8001 is now free"
fi
echo ""

# Step 5: Stop RPyC service and restart it
echo "[5/5] Restarting RPyC server..."
systemctl stop mt5-rpyc 2>/dev/null || true
sleep 2

# Kill any remaining RPyC processes
pkill -9 -f "mt5linux.*8001" 2>/dev/null || true
sleep 2

# Start RPyC server
systemctl start mt5-rpyc
sleep 5

# Check if it started
if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC service started"
else
    echo "⚠️  RPyC service failed, checking logs..."
    journalctl -u mt5-rpyc -n 10 --no-pager
    echo ""
    echo "   Trying manual start..."
    cd /opt/mt5-api-bridge
    source venv/bin/activate
    nohup python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe > /tmp/rpyc_manual.log 2>&1 &
    sleep 3
fi

# Verify port 8001 is now used by RPyC
echo ""
echo "📊 Port 8001 Status:"
ss -tlnp | grep ":8001" || echo "   Port 8001 is not in use"
echo ""

# Wait and test
echo "⏳ Waiting 10 seconds for RPyC to initialize..."
sleep 10

echo ""
echo "🧪 Testing RPyC Connection..."
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   🔌 Connecting to MT5 via RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    time.sleep(3)
    
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ MT5 Terminal connected!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        
        account = mt5.account_info()
        if account:
            print(f"      ✅ Account: {account.login} @ {account.server}")
            print(f"      Balance: {account.balance}")
        else:
            print(f"      ⚠️  Not logged in")
        sys.exit(0)
    else:
        print("   ⚠️  Connected but terminal_info() is None")
        print("   This might mean MT5 Terminal is still initializing")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not running")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

TEST_RESULT=$?

echo ""
echo "==========================="
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ Port 8001 Fixed! RPyC is connected to MT5"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   2. View logs: journalctl -u mt5-rpyc -f"
else
    echo "❌ Connection Still Failing"
    echo ""
    echo "📋 Check:"
    echo "   1. Port 8001 status: ss -tlnp | grep 8001"
    echo "   2. RPyC logs: journalctl -u mt5-rpyc -n 30"
    echo "   3. MT5 processes: ps aux | grep terminal"
fi
echo ""

