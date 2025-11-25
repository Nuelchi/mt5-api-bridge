#!/bin/bash
# Next Steps After Successful Installation
# Run these commands one by one on your VPS

set -e

cd /opt/mt5-api-bridge

echo "🚀 MT5 API Bridge - Next Steps"
echo "=============================="
echo ""

# Step 1: Test MT5 Connection
echo "📋 Step 1: Testing MT5 Connection..."
echo "===================================="
source venv/bin/activate
python3 test_mt5_connection.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ MT5 connection test passed!"
    echo ""
else
    echo ""
    echo "❌ MT5 connection test failed. Please check credentials."
    exit 1
fi

# Step 2: Create .env file
echo "📋 Step 2: Creating .env file..."
echo "================================="
cat > .env <<'EOF'
# Supabase Authentication
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M

# Server Configuration
PORT=8001
HOST=0.0.0.0

# CORS Origins (comma-separated)
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000

# Domain
DOMAIN=trade.trainflow.dev

# Logging
LOG_LEVEL=INFO
EOF

echo "✅ .env file created"
echo ""

# Step 3: Test JWT Authentication
echo "📋 Step 3: Testing JWT Authentication..."
echo "========================================"
if [ -f "test_token.py" ]; then
    python3 test_token.py
    if [ $? -eq 0 ]; then
        echo "✅ JWT authentication test passed!"
    else
        echo "⚠️  JWT authentication test failed (may need valid token)"
    fi
else
    echo "⚠️  test_token.py not found, skipping JWT test"
fi
echo ""

# Step 4: Test API Server Locally
echo "📋 Step 4: Testing API Server (local)..."
echo "========================================"
echo "Starting server in background for 5 seconds..."
source venv/bin/activate
timeout 5 uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001 || true
echo "✅ Server test complete"
echo ""

# Step 5: Create systemd service
echo "📋 Step 5: Creating systemd service..."
echo "======================================"
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
ExecStart=/opt/mt5-api-bridge/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-api
echo "✅ systemd service created and enabled"
echo ""

# Step 6: Start service
echo "📋 Step 6: Starting MT5 API service..."
echo "======================================"
systemctl start mt5-api
sleep 2
systemctl status mt5-api --no-pager -l
echo ""

# Step 7: Test API endpoint
echo "📋 Step 7: Testing API endpoint..."
echo "==================================="
sleep 2
curl -s http://localhost:8001/health || echo "⚠️  Health check failed (service may still be starting)"
echo ""
echo ""

# Summary
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "📊 Service Status:"
systemctl is-active mt5-api && echo "   ✅ Service is running" || echo "   ❌ Service is not running"
echo ""
echo "🔗 Next Steps:"
echo "   1. Configure Nginx: See Nginx configuration in repository"
echo "   2. Set up SSL: certbot --nginx -d trade.trainflow.dev"
echo "   3. Test API: curl http://localhost:8001/health"
echo "   4. View logs: journalctl -u mt5-api -f"
echo ""



