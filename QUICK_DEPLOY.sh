#!/bin/bash
# Quick Deploy Script - Run this on your VPS
# This script does everything in one go

set -e

echo "🚀 MT5 API Bridge - Quick Deploy"
echo "================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo bash QUICK_DEPLOY.sh)"
    exit 1
fi

APP_DIR="/opt/mt5-api-bridge"

# Step 1: Clean up
echo "🧹 Step 1: Cleaning up old directories..."
rm -rf /opt/mt5-api-bridge /opt/MetaTrader5-Docker /opt/mt5 2>/dev/null || true
echo "✅ Cleanup done"

# Step 2: Update system
echo ""
echo "📦 Step 2: Updating system..."
apt update -qq
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx > /dev/null 2>&1
echo "✅ System updated"

# Step 3: Clone repo
echo ""
echo "📥 Step 3: Cloning repository..."
mkdir -p $APP_DIR
cd $APP_DIR
git clone https://github.com/Nuelchi/mt5-api-bridge.git . 2>/dev/null || git pull
echo "✅ Repository cloned"

# Step 4: Setup Python
echo ""
echo "🐍 Step 4: Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q
pip install mt5linux -q || echo "⚠️  mt5linux install failed, may need Wine"
echo "✅ Python environment ready"

# Step 5: Create .env
echo ""
echo "⚙️  Step 5: Creating .env file..."
cat > .env <<'EOF'
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M
PORT=8001
HOST=0.0.0.0
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000
DOMAIN=trade.trainflow.dev
LOG_LEVEL=INFO
EOF
echo "✅ .env file created"

# Step 6: Test MT5 connection
echo ""
echo "🧪 Step 6: Testing MT5 connection..."
python3 test_mt5_connection.py || echo "⚠️  MT5 test failed - check credentials"

# Step 7: Create systemd service
echo ""
echo "⚙️  Step 7: Creating systemd service..."
cat > /etc/systemd/system/mt5-api.service <<EOF
[Unit]
Description=MT5 API Bridge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api
sleep 2

if systemctl is-active --quiet mt5-api; then
    echo "✅ Service is running!"
else
    echo "❌ Service failed - check: journalctl -u mt5-api"
fi

# Step 8: Test
echo ""
echo "🧪 Step 8: Testing API..."
sleep 1
curl -s http://localhost:8001/health | head -20 || echo "⚠️  API not responding"

echo ""
echo "=" * 60
echo "✅ Deployment Complete!"
echo "=" * 60
echo ""
echo "📋 Next Steps:"
echo "   1. Check service: systemctl status mt5-api"
echo "   2. View logs: journalctl -u mt5-api -f"
echo "   3. Test health: curl http://localhost:8001/health"
echo "   4. Configure Nginx: ./deploy_vps.sh"
echo ""

