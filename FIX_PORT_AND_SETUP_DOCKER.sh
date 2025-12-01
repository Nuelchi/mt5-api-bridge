#!/bin/bash
# Fix port conflict and set up Docker MT5
# Changes API service to port 8000, Docker MT5 uses 8001

set -e

echo "🔧 Fixing port conflict and setting up Docker MT5"
echo "=================================================="
echo ""

# Step 1: Stop API service
echo "[1/5] Stopping MT5 API service..."
echo "---------------------------------"
systemctl stop mt5-api
echo "✅ Service stopped"
echo ""

# Step 2: Update systemd service to use port 8000
echo "[2/5] Updating API service to use port 8000..."
echo "----------------------------------------------"
cat > /etc/systemd/system/mt5-api.service <<'EOF'
[Unit]
Description=MT5 API Bridge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mt5-api-bridge
Environment="PATH=/opt/mt5-api-bridge/venv/bin"
EnvironmentFile=/opt/mt5-api-bridge/.env
ExecStart=/opt/mt5-api-bridge/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "✅ Service updated to use port 8000"
echo ""

# Step 3: Update .env file
echo "[3/5] Updating .env file..."
echo "--------------------------"
cd /opt/mt5-api-bridge
if grep -q "^PORT=" .env; then
    sed -i 's/^PORT=.*/PORT=8000/' .env
else
    echo "PORT=8000" >> .env
fi

# Add MT5 RPC settings if not present
if ! grep -q "^MT5_RPC_HOST=" .env; then
    echo "MT5_RPC_HOST=localhost" >> .env
fi
if ! grep -q "^MT5_RPC_PORT=" .env; then
    echo "MT5_RPC_PORT=8001" >> .env
fi

echo "✅ .env file updated"
echo ""

# Step 4: Update Nginx config to proxy to port 8000
echo "[4/5] Updating Nginx configuration..."
echo "-------------------------------------"
if [ -f "/etc/nginx/sites-available/mt5-api" ]; then
    sed -i 's|proxy_pass http://127.0.0.1:8001|proxy_pass http://127.0.0.1:8000|g' /etc/nginx/sites-available/mt5-api
    nginx -t && systemctl reload nginx
    echo "✅ Nginx updated"
else
    echo "⚠️  Nginx config not found, skipping"
fi
echo ""

# Step 5: Start API service
echo "[5/5] Starting API service on port 8000..."
echo "------------------------------------------"
systemctl start mt5-api
sleep 2
if systemctl is-active --quiet mt5-api; then
    echo "✅ API service running on port 8000"
else
    echo "⚠️  Service may have issues, check: systemctl status mt5-api"
fi
echo ""

# Now start Docker MT5
echo "🐳 Starting Docker MT5 container..."
echo "===================================="
echo ""

# Check if container already exists
if docker ps -a | grep -q mt5; then
    echo "   Cleaning up existing container..."
    docker stop mt5 2>/dev/null || true
    docker rm mt5 2>/dev/null || true
fi

# Start Docker container
docker run -d \
    --name mt5 \
    --restart unless-stopped \
    -p 3000:3000 \
    -p 8001:8001 \
    -v mt5-config:/config \
    gmag11/metatrader5_vnc

echo "   ✅ Docker container starting..."
echo "   This will take 5-10 minutes on first run"
echo ""

echo "📋 Summary:"
echo "   - API Service: Port 8000 (http://localhost:8000)"
echo "   - Docker MT5 RPC: Port 8001"
echo "   - VNC Access: Port 3000 (http://147.182.206.223:3000)"
echo "   - Public API: https://trade.trainflow.dev (via Nginx)"
echo ""
echo "💡 Next steps:"
echo "   1. Wait 2-3 minutes for Docker container to initialize"
echo "   2. Access VNC: http://147.182.206.223:3000"
echo "   3. Log in to MT5 Terminal via VNC"
echo "   4. Test connection: curl http://localhost:8000/health"
echo ""

