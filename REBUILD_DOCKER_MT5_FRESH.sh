#!/bin/bash
# Rebuild Docker MT5 from scratch - clean installation

set -e

echo "🔄 Rebuilding Docker MT5 from Scratch"
echo "======================================"
echo ""
echo "This will:"
echo "  1. Stop and remove existing container"
echo "  2. Remove Docker volume (fresh start)"
echo "  3. Pull fresh image"
echo "  4. Start new container"
echo "  5. Wait for MT5 to be ready"
echo ""

cd /opt/mt5-api-bridge

# Step 1: Stop and remove existing container
echo "[1/5] Stopping and removing existing container..."
echo "================================================="
if docker ps -a | grep -q mt5; then
    echo "   Stopping container..."
    docker stop mt5 2>/dev/null || true
    echo "   Removing container..."
    docker rm mt5 2>/dev/null || true
    echo "   ✅ Container removed"
else
    echo "   ✅ No existing container"
fi
echo ""

# Step 2: Remove Docker volume (fresh start)
echo "[2/5] Removing Docker volume (fresh start)..."
echo "============================================="
read -p "   Remove Docker volume? This will delete all MT5 data. (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if docker volume ls | grep -q mt5-config; then
        echo "   Removing volume..."
        docker volume rm mt5-config 2>/dev/null || true
        echo "   ✅ Volume removed"
    else
        echo "   ✅ No existing volume"
    fi
else
    echo "   ⏭️  Keeping existing volume"
fi
echo ""

# Step 3: Pull fresh image
echo "[3/5] Pulling fresh Docker image..."
echo "==================================="
echo "   This may take a few minutes..."
docker pull gmag11/metatrader5_vnc:latest
echo "   ✅ Image pulled"
echo ""

# Step 4: Start new container
echo "[4/5] Starting new Docker container..."
echo "======================================"
docker run -d \
    --name mt5 \
    --restart unless-stopped \
    -p 3000:3000 \
    -p 8001:8001 \
    -v mt5-config:/config \
    gmag11/metatrader5_vnc

echo "   ✅ Container started"
echo ""

# Step 5: Wait for MT5 to be ready
echo "[5/5] Waiting for MT5 to be ready..."
echo "===================================="
echo "   This will take 5-10 minutes on first run"
echo "   (MT5 Terminal needs to install and start)"
echo ""

MAX_WAIT=600  # 10 minutes
WAITED=0
READY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    # Check if port is open
    if timeout 2 bash -c "echo > /dev/tcp/localhost/8001" 2>/dev/null; then
        echo "   ⏳ Port 8001 is open, testing connection... (${WAITED}s / ${MAX_WAIT}s)"
        
        source venv/bin/activate
        python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Try to initialize
    if mt5.initialize():
        print("   ✅ MT5 initialized!")
        
        # Try to get account info
        time.sleep(2)
        account = mt5.account_info()
        if account:
            print(f"   ✅ MT5 is logged in!")
            print(f"      Account: {account.login}")
            sys.exit(0)
        else:
            print("   ⏳ MT5 initialized but not logged in yet")
            sys.exit(1)
    else:
        error = mt5.last_error()
        print(f"   ⏳ Initialize returned False: {error}")
        sys.exit(1)
        
except EOFError:
    print("   ⏳ Connection not ready yet")
    sys.exit(1)
except Exception as e:
    print(f"   ⏳ Error: {str(e)[:60]}")
    sys.exit(1)
PYEOF

        if [ $? -eq 0 ]; then
            READY=true
            break
        fi
    else
        echo "   ⏳ Port 8001 not responding yet... (${WAITED}s / ${MAX_WAIT}s)"
    fi
    
    WAITED=$((WAITED + 15))
    sleep 15
done

echo ""

if [ "$READY" = true ]; then
    echo "✅ SUCCESS! MT5 is ready and logged in!"
    echo ""
    echo "📋 Final Status:"
    source venv/bin/activate
    python3 <<PYEOF
from mt5linux import MetaTrader5
mt5 = MetaTrader5(host='localhost', port=8001)
mt5.initialize()
account = mt5.account_info()
if account:
    print(f"   ✅ Account: {account.login}")
    print(f"   ✅ Server: {account.server}")
    print(f"   ✅ Balance: {account.balance}")
PYEOF

    echo ""
    echo "🚀 Next steps:"
    echo "   1. Restart API service: systemctl restart mt5-api"
    echo "   2. Test API: python3 test_api_with_auth.py https://trade.trainflow.dev"
else
    echo "⚠️  MT5 did not become ready after ${MAX_WAIT} seconds"
    echo ""
    echo "💡 This is normal on first run - MT5 Terminal needs time to install"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Check Docker logs: docker logs mt5 --tail 50"
    echo "   2. Access MT5 GUI: http://147.182.206.223:3000"
    echo "   3. Log in to MT5 Terminal manually:"
    echo "      Server: MetaQuotes-Demo"
    echo "      Login: 5042856355"
    echo "      Password: V!QzRxQ7"
    echo "   4. Wait 2-3 minutes after logging in"
    echo "   5. Test connection: python3 -c \"from mt5linux import MetaTrader5; mt5 = MetaTrader5(host='localhost', port=8001); print('Connected!' if mt5.initialize() and mt5.account_info() else 'Not ready')\""
    echo "   6. Restart API service: systemctl restart mt5-api"
fi

echo ""

