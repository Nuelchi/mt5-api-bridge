#!/bin/bash
# Setup MetaTrader5 using Docker (the proven working solution)

set -e

echo "🐳 Setting up MetaTrader5 with Docker"
echo "======================================"
echo ""
echo "This will use the proven Docker solution from mt5-works"
echo ""

cd /opt/mt5-api-bridge

# Step 1: Install Docker if not installed
echo "[1/6] Checking Docker installation..."
echo "====================================="
if ! command -v docker &> /dev/null; then
    echo "   Docker not found. Installing..."
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo "   ✅ Docker installed"
else
    echo "   ✅ Docker is already installed"
    docker --version
fi
echo ""

# Step 2: Stop and remove existing MT5 container if it exists
echo "[2/6] Cleaning up existing MT5 containers..."
echo "=============================================="
if docker ps -a | grep -q mt5; then
    echo "   Stopping existing MT5 container..."
    docker stop mt5 2>/dev/null || true
    docker rm mt5 2>/dev/null || true
    echo "   ✅ Cleaned up"
else
    echo "   ✅ No existing containers"
fi
echo ""

# Step 3: Create Docker volume for MT5 config
echo "[3/6] Creating Docker volume for MT5 config..."
echo "=============================================="
if ! docker volume ls | grep -q mt5-config; then
    docker volume create mt5-config
    echo "   ✅ Volume created"
else
    echo "   ✅ Volume already exists"
fi
echo ""

# Step 4: Pull and run the MT5 Docker image
echo "[4/6] Starting MetaTrader5 Docker container..."
echo "=============================================="
echo "   This will:"
echo "   - Download the Docker image (first time only, ~4GB)"
echo "   - Install MT5 Terminal, Windows Python, and RPyC server"
echo "   - Start everything automatically"
echo ""
echo "   This may take 5-10 minutes on first run..."
echo ""

docker run -d \
    --name mt5 \
    --restart unless-stopped \
    -p 3000:3000 \
    -p 8001:8001 \
    -v mt5-config:/config \
    gmag11/metatrader5_vnc

echo "   ✅ Docker container started"
echo ""

# Step 5: Wait for MT5 to be ready
echo "[5/6] Waiting for MT5 to be ready..."
echo "====================================="
echo "   Waiting 60 seconds for MT5 Terminal and RPyC server to initialize..."
echo "   (This is normal on first run - MT5 needs to install and start)"
echo ""

for i in {1..12}; do
    echo -ne "   Waiting... ($((i*5))s / 60s)\r"
    sleep 5
    
    # Check if RPyC server is responding
    if timeout 2 bash -c "echo > /dev/tcp/localhost/8001" 2>/dev/null; then
        echo ""
        echo "   ✅ RPyC server is responding!"
        break
    fi
done

echo ""
echo "   Checking container status..."
docker ps | grep mt5 || echo "   ⚠️  Container may still be starting"
echo ""

# Step 6: Test connection
echo "[6/6] Testing MT5 connection..."
echo "=============================="
source venv/bin/activate

echo "   Testing RPyC connection..."
python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   Connecting to RPyC server...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected to RPyC server")
    
    print("   Waiting 5 seconds for MT5 to be ready...")
    time.sleep(5)
    
    print("   Initializing MT5...")
    if mt5.initialize():
        print("   ✅ MT5 initialized successfully!")
        
        # Try to get version
        try:
            version = mt5.version()
            print(f"   ✅ MT5 Version: {version}")
        except:
            print("   ⚠️  Could not get version (but initialized)")
        
        # Try to get terminal info
        try:
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal Info: Build {terminal_info.build}")
            else:
                print("   ⚠️  Terminal info is None (but initialized)")
        except:
            print("   ⚠️  Could not get terminal info")
        
        print("")
        print("   ✅ SUCCESS! MT5 is working via Docker!")
        sys.exit(0)
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False: {error}")
        print("   But this might be OK - MT5 may need more time")
        sys.exit(1)
        
except TimeoutError as e:
    print(f"   ⏳ Timeout: {e}")
    print("   MT5 may need more time to initialize")
    print("   Wait a few minutes and try again")
    sys.exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

TEST_RESULT=$?
echo ""

if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ SUCCESS! MT5 Docker setup is complete!"
    echo ""
    echo "📋 Summary:"
    echo "   - Docker container: Running"
    echo "   - RPyC server: Port 8001"
    echo "   - VNC access: Port 3000 (http://your-vps-ip:3000)"
    echo "   - MT5 Terminal: Running inside Docker"
    echo ""
    echo "🌐 Access MT5 Terminal GUI:"
    echo "   Open in browser: http://$(hostname -I | awk '{print $1}'):3000"
    echo "   Or: http://147.182.206.223:3000"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Access VNC to log in to MT5 Terminal (if needed)"
    echo "   2. Update your .env file with:"
    
    # Update .env file if it exists
    if [ -f .env ]; then
        echo "   Updating .env file..."
        if grep -q "MT5_RPC_HOST" .env; then
            sed -i 's/^MT5_RPC_HOST=.*/MT5_RPC_HOST=localhost/' .env
        else
            echo "MT5_RPC_HOST=localhost" >> .env
        fi
        
        if grep -q "MT5_RPC_PORT" .env; then
            sed -i 's/^MT5_RPC_PORT=.*/MT5_RPC_PORT=8001/' .env
        else
            echo "MT5_RPC_PORT=8001" >> .env
        fi
        echo "   ✅ .env file updated"
    else
        echo "   Create .env file with:"
        echo "      MT5_RPC_HOST=localhost"
        echo "      MT5_RPC_PORT=8001"
    fi
    
    echo "   3. Run: ./TEST_AND_SETUP.sh to complete API setup"
    echo ""
    echo "💡 Useful commands:"
    echo "   - View logs: docker logs mt5"
    echo "   - Stop: docker stop mt5"
    echo "   - Start: docker start mt5"
    echo "   - Restart: docker restart mt5"
    echo "   - Remove: docker stop mt5 && docker rm mt5"
else
    echo "⚠️  Connection test had issues, but container is running"
    echo ""
    echo "💡 This is normal on first run - MT5 needs time to install"
    echo "   Wait 2-3 more minutes, then check:"
    echo "   1. Container logs: docker logs mt5"
    echo "   2. Test again: python3 -c \"from mt5linux import MetaTrader5; mt5 = MetaTrader5(host='localhost', port=8001); print('Connected!' if mt5.initialize() else 'Not ready')\""
    echo ""
    echo "   Or access VNC to see MT5 Terminal: http://147.182.206.223:3000"
fi

echo ""

