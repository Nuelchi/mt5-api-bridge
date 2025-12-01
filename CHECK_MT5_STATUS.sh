#!/bin/bash
# Check Docker MT5 container status and test connection

echo "🔍 Checking Docker MT5 Status"
echo "============================="
echo ""

# Check if container is running
echo "[1/4] Checking Docker container..."
echo "----------------------------------"
if docker ps | grep -q mt5; then
    echo "✅ Docker container is running"
    docker ps | grep mt5
else
    echo "❌ Docker container is not running"
    echo "   Checking if it exists..."
    docker ps -a | grep mt5
    echo ""
    echo "   Try starting it: docker start mt5"
    exit 1
fi
echo ""

# Check container logs
echo "[2/4] Checking container logs (last 20 lines)..."
echo "-----------------------------------------------"
docker logs mt5 --tail 20
echo ""

# Check if ports are listening
echo "[3/4] Checking ports..."
echo "----------------------"
if ss -tlnp | grep -q ":8001"; then
    echo "✅ Port 8001 (RPyC) is listening"
else
    echo "⚠️  Port 8001 not listening yet (may still be starting)"
fi

if ss -tlnp | grep -q ":3000"; then
    echo "✅ Port 3000 (VNC) is listening"
else
    echo "⚠️  Port 3000 not listening yet"
fi
echo ""

# Test MT5 connection
echo "[4/4] Testing MT5 connection..."
echo "-------------------------------"
cd /opt/mt5-api-bridge
source venv/bin/activate

python3 <<EOF
from mt5linux import MetaTrader5
import time
import sys

print("   Connecting to RPyC server (localhost:8001)...")
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected to RPyC server")
    
    print("   Initializing MT5...")
    time.sleep(2)  # Give it a moment
    
    if mt5.initialize():
        print("   ✅ MT5 initialized!")
        
        # Try to get account info
        account = mt5.account_info()
        if account:
            print(f"   ✅ Account connected!")
            print(f"      Login: {account.login}")
            print(f"      Server: {account.server}")
            print(f"      Balance: {account.balance}")
        else:
            print("   ⚠️  MT5 initialized but not logged in")
            print("      Access VNC: http://147.182.206.223:3000")
            print("      Log in to MT5 Terminal via VNC")
        
        # Try to get version
        try:
            version = mt5.version()
            print(f"   ✅ MT5 Version: {version}")
        except:
            pass
            
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False")
        print(f"      Error: {error}")
        print("   📝 Next: Access VNC and log in to MT5")
        sys.exit(1)
        
except ConnectionRefusedError:
    print("   ❌ Connection refused - RPyC server not ready yet")
    print("      Wait 2-3 more minutes and try again")
    sys.exit(1)
except Exception as e:
    print(f"   ⚠️  Error: {e}")
    print("   💡 The container may still be starting")
    print("      Check logs: docker logs mt5")
    sys.exit(1)
EOF

CONNECTION_TEST=$?
echo ""

if [ $CONNECTION_TEST -eq 0 ]; then
    echo "✅ SUCCESS! MT5 is connected and working!"
    echo ""
    echo "🌐 Access MT5 Terminal GUI:"
    echo "   http://147.182.206.223:3000"
    echo ""
    echo "🧪 Test API endpoints:"
    echo "   curl https://trade.trainflow.dev/health"
    echo "   curl -H 'Authorization: Bearer YOUR_JWT' https://trade.trainflow.dev/api/v1/account/info"
else
    echo "⚠️  MT5 connection test had issues"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Wait 2-3 more minutes for container to fully start"
    echo "   2. Check logs: docker logs mt5"
    echo "   3. Access VNC: http://147.182.206.223:3000"
    echo "   4. Log in to MT5 Terminal via VNC"
    echo "   5. Run this script again"
fi

echo ""

