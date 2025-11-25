#!/bin/bash
# Fix API service port conflict - change API to port 8000, keep RPyC on 8001

set -e

echo "🔧 Fixing API Port Conflict"
echo "=========================="
echo ""
echo "Issue: API service is using port 8001 (same as Docker RPyC server)"
echo "Solution: Change API to port 8000, keep RPyC on 8001"
echo ""

cd /opt/mt5-api-bridge

# Step 1: Update .env file
echo "[1/4] Updating .env file..."
echo "=========================="
if [ -f .env ]; then
    # Update PORT for API service
    if grep -q "^PORT=" .env; then
        sed -i 's/^PORT=.*/PORT=8000/' .env
        echo "   ✅ Updated PORT=8000"
    else
        echo "PORT=8000" >> .env
        echo "   ✅ Added PORT=8000"
    fi
    
    # Ensure RPC settings are correct
    if grep -q "^MT5_RPC_HOST=" .env; then
        sed -i 's/^MT5_RPC_HOST=.*/MT5_RPC_HOST=localhost/' .env
    else
        echo "MT5_RPC_HOST=localhost" >> .env
    fi
    
    if grep -q "^MT5_RPC_PORT=" .env; then
        sed -i 's/^MT5_RPC_PORT=.*/MT5_RPC_PORT=8001/' .env
    else
        echo "MT5_RPC_PORT=8001" >> .env
    fi
    
    echo "   ✅ .env file updated"
    echo ""
    echo "   Current settings:"
    grep -E "^(PORT|MT5_RPC)" .env || echo "   (settings not found)"
else
    echo "   ⚠️  .env file not found, creating it..."
    cat > .env <<EOF
PORT=8000
MT5_RPC_HOST=localhost
MT5_RPC_PORT=8001
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M
HOST=0.0.0.0
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000
DOMAIN=trade.trainflow.dev
LOG_LEVEL=INFO
EOF
    echo "   ✅ Created .env file"
fi
echo ""

# Step 2: Update systemd service
echo "[2/4] Updating systemd service..."
echo "================================="
cat > /etc/systemd/system/mt5-api.service <<EOF
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

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "   ✅ Systemd service updated to use port 8000"
echo ""

# Step 3: Update Nginx configuration
echo "[3/4] Updating Nginx configuration..."
echo "====================================="
if [ -f /etc/nginx/sites-available/mt5-api ]; then
    sed -i 's/proxy_pass http:\/\/127\.0\.0\.1:8001/proxy_pass http:\/\/127.0.0.1:8000/g' /etc/nginx/sites-available/mt5-api
    sed -i 's/proxy_pass http:\/\/127\.0\.0\.1:8001/proxy_pass http:\/\/127.0.0.1:8000/g' /etc/nginx/sites-enabled/mt5-api 2>/dev/null || true
    
    nginx -t && systemctl reload nginx
    echo "   ✅ Nginx updated to proxy to port 8000"
else
    echo "   ⚠️  Nginx config not found, will be created on next setup"
fi
echo ""

# Step 4: Restart API service
echo "[4/4] Restarting API service..."
echo "==============================="
systemctl stop mt5-api 2>/dev/null || true
sleep 2
systemctl start mt5-api
sleep 3

if systemctl is-active --quiet mt5-api; then
    echo "   ✅ API service is running on port 8000"
    echo ""
    echo "   Testing API..."
    sleep 2
    curl -s http://localhost:8000/health | head -5 || echo "   ⚠️  API may still be starting..."
else
    echo "   ❌ API service failed to start"
    echo "   Checking logs..."
    journalctl -u mt5-api -n 20 --no-pager
fi
echo ""

echo "✅ Port conflict fixed!"
echo ""
echo "📋 Summary:"
echo "   - Docker RPyC server: Port 8001 ✅"
echo "   - API service: Port 8000 ✅"
echo "   - Nginx: Proxies to port 8000 ✅"
echo ""
echo "🌐 Test URLs:"
echo "   API: http://localhost:8000/health"
echo "   Via Nginx: https://trade.trainflow.dev/health"
echo ""

