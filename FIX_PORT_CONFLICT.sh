#!/bin/bash
# Fix port conflict between Docker and RPyC server

echo "🔧 Fixing Port 8001 Conflict"
echo "============================"
echo ""

# Step 1: Check what's using port 8001
echo "[1/4] Checking port 8001 usage..."
PORT_8001=$(ss -tlnp | grep ":8001")
if [ -n "$PORT_8001" ]; then
    echo "✅ Port 8001 is in use:"
    echo "$PORT_8001"
    echo ""
    
    # Check if it's Docker
    if echo "$PORT_8001" | grep -q "docker-proxy"; then
        echo "⚠️  Port 8001 is used by Docker container"
        DOCKER_CONTAINER=$(docker ps | grep "8001" | head -1)
        if [ -n "$DOCKER_CONTAINER" ]; then
            echo "   Docker container:"
            echo "$DOCKER_CONTAINER"
        fi
    else
        echo "   Port 8001 is used by another process"
    fi
else
    echo "✅ Port 8001 is free"
fi
echo ""

# Step 2: Check MT5 Terminal processes
echo "[2/4] Checking MT5 Terminal processes..."
MT5_PROCS=$(ps aux | grep -E "terminal64.exe|terminal.exe" | grep -v grep)
if [ -n "$MT5_PROCS" ]; then
    echo "✅ Found MT5 Terminal processes:"
    echo "$MT5_PROCS"
    echo ""
    echo "   These are native MT5 processes (not in Docker)"
else
    echo "❌ No native MT5 Terminal processes found"
fi
echo ""

# Step 3: Ask user what to do
echo "[3/4] Resolution Options:"
echo "========================="
echo ""
echo "Option 1: Stop Docker container and use native MT5 (Recommended)"
echo "   - Docker container is blocking port 8001"
echo "   - Native MT5 processes are already running"
echo "   - This will free port 8001 for RPyC"
echo ""
echo "Option 2: Use Docker MT5 (if it has RPyC server inside)"
echo "   - Keep Docker container running"
echo "   - Configure to use Docker's RPyC server"
echo ""
echo "Option 3: Use different port for RPyC"
echo "   - Keep Docker on 8001"
echo "   - Use port 8002 for native RPyC"
echo ""

# Step 4: Implement Option 1 (stop Docker, use native)
echo "[4/4] Implementing Option 1: Stop Docker, use native MT5..."
echo ""

# Stop Docker container
if docker ps | grep -q "mt5.*8001"; then
    echo "   Stopping Docker container 'mt5'..."
    docker stop mt5
    sleep 3
    
    if docker ps | grep -q "mt5"; then
        echo "   ⚠️  Docker container still running, forcing stop..."
        docker kill mt5 2>/dev/null || true
        sleep 2
    fi
    
    echo "✅ Docker container stopped"
else
    echo "✅ No Docker container to stop"
fi
echo ""

# Verify port 8001 is free
echo "   Verifying port 8001 is free..."
sleep 2
if ss -tlnp | grep -q ":8001"; then
    echo "   ⚠️  Port 8001 still in use:"
    ss -tlnp | grep ":8001"
    echo "   Trying to kill the process..."
    # Get PID of process using port 8001
    PORT_PID=$(ss -tlnp | grep ":8001" | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$PORT_PID" ]; then
        kill -9 $PORT_PID 2>/dev/null || true
        sleep 2
    fi
else
    echo "✅ Port 8001 is now free"
fi
echo ""

# Start RPyC server
echo "   Starting RPyC server..."
systemctl start mt5-rpyc
sleep 5

if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server started successfully"
else
    echo "⚠️  RPyC service failed, starting manually..."
    cd /opt/mt5-api-bridge
    source venv/bin/activate
    nohup python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe > /tmp/rpyc.log 2>&1 &
    sleep 3
fi

# Verify port 8001 is now used by RPyC
if ss -tlnp | grep ":8001" | grep -q "python"; then
    echo "✅ Port 8001 is now used by RPyC server"
else
    echo "⚠️  Port 8001 status unclear"
    ss -tlnp | grep ":8001" || echo "   Port 8001 is not in use"
fi
echo ""

# Test connection
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
    
    time.sleep(2)
    
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
    echo "✅ Port Conflict Fixed! RPyC is now connected to MT5"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   2. View logs: journalctl -u mt5-rpyc -f"
    echo ""
    echo "⚠️  Note: Docker container 'mt5' has been stopped."
    echo "   If you need it, restart with: docker start mt5"
else
    echo "❌ Connection Still Failing"
    echo ""
    echo "📋 Troubleshooting:"
    echo "   1. Check RPyC logs: journalctl -u mt5-rpyc -n 50"
    echo "   2. Check if native MT5 Terminal is accessible"
    echo "   3. Verify port 8001: ss -tlnp | grep 8001"
fi
echo ""
