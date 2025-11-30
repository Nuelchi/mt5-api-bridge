#!/bin/bash
# Fix RPyC connection to MT5 Terminal

echo "🔧 Fixing RPyC Connection to MT5"
echo "================================"
echo ""

# Step 1: Check Docker container
echo "[1/5] Checking Docker MT5 Container..."
DOCKER_MT5=$(docker ps | grep -E "mt5|8001" | head -1)
if [ -n "$DOCKER_MT5" ]; then
    echo "✅ Found Docker container using port 8001:"
    echo "$DOCKER_MT5"
    echo ""
    echo "   This might be the MT5 Docker container"
    echo "   Checking if MT5 Terminal is accessible inside container..."
    docker exec mt5 ps aux | grep -E "terminal|mt5" | grep -v grep || echo "   No MT5 process found in container"
else
    echo "❌ No Docker container found on port 8001"
fi
echo ""

# Step 2: Check native MT5 processes
echo "[2/5] Checking Native MT5 Terminal Processes..."
MT5_PROCS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep)
if [ -n "$MT5_PROCS" ]; then
    echo "✅ Found MT5 Terminal processes:"
    echo "$MT5_PROCS"
    echo ""
    echo "   These processes are running but RPyC can't connect"
else
    echo "❌ No MT5 Terminal processes found"
fi
echo ""

# Step 3: Check RPyC server
echo "[3/5] Checking RPyC Server..."
if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
    echo "✅ RPyC service is running"
    RPYC_PID=$(systemctl show -p MainPID --value mt5-rpyc)
    echo "   PID: $RPYC_PID"
    ps -p $RPYC_PID -o lstart=,cmd= | head -1
else
    echo "❌ RPyC service is not running"
fi

# Check if port 8001 is in use
if ss -tlnp | grep -q ":8001"; then
    echo "✅ Port 8001 is in use:"
    ss -tlnp | grep ":8001"
else
    echo "❌ Port 8001 is not in use"
fi
echo ""

# Step 4: Stop conflicting services
echo "[4/5] Stopping conflicting services..."
echo "   Stopping RPyC service..."
systemctl stop mt5-rpyc 2>/dev/null || true
sleep 2

# Kill any manual RPyC processes
pkill -f "mt5linux.*8001" 2>/dev/null || true
sleep 2
echo "✅ Services stopped"
echo ""

# Step 5: Determine which MT5 to use and start RPyC accordingly
echo "[5/5] Starting RPyC Server..."
cd /opt/mt5-api-bridge
source venv/bin/activate

# Check if we should use Docker or native
if docker ps | grep -q "mt5.*8001"; then
    echo "   Docker container found - RPyC should connect to Docker MT5"
    echo "   However, RPyC needs to connect to native MT5, not Docker"
    echo ""
    echo "   Option 1: Use native MT5 Terminal (recommended)"
    echo "   Option 2: Configure RPyC to connect to Docker MT5"
    echo ""
    echo "   For now, starting RPyC to connect to native MT5..."
    
    # Start RPyC server
    systemctl start mt5-rpyc
    sleep 5
    
    if systemctl is-active --quiet mt5-rpyc; then
        echo "✅ RPyC service started"
    else
        echo "⚠️  RPyC service failed, starting manually..."
        nohup python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe > /tmp/rpyc.log 2>&1 &
        sleep 3
    fi
else
    echo "   No Docker container - using native MT5"
    systemctl start mt5-rpyc
    sleep 5
fi

# Wait and test connection
echo ""
echo "⏳ Waiting 10 seconds for RPyC to initialize..."
sleep 10

echo ""
echo "🧪 Testing RPyC Connection..."
python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   🔌 Connecting to MT5 via RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    time.sleep(2)
    
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ MT5 Terminal connected!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        
        account = mt5.account_info()
        if account:
            print(f"      ✅ Account: {account.login} @ {account.server}")
        else:
            print(f"      ⚠️  Not logged in")
        sys.exit(0)
    else:
        print("   ⚠️  Connected but terminal_info() is None")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    sys.exit(1)
PYEOF

TEST_RESULT=$?

echo ""
echo "==========================="
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ RPyC Connection Fixed!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   2. View logs: journalctl -u mt5-rpyc -f"
else
    echo "❌ RPyC Connection Still Failing"
    echo ""
    echo "📋 Troubleshooting:"
    echo "   1. Check RPyC logs: journalctl -u mt5-rpyc -n 50"
    echo "   2. Check if MT5 Terminal is actually accessible"
    echo "   3. Try restarting MT5 Terminal: ./FIX_MT5_CRASH.sh"
    echo "   4. Check Docker container: docker logs mt5"
fi
echo ""

