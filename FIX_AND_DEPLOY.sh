#!/bin/bash
# Fix dpkg locks and continue deployment
# Run this when you have lock issues

set -e

echo "🔧 Fixing system locks and continuing deployment..."
echo "==================================================="

# Step 1: Kill any stuck apt/dpkg processes
echo ""
echo "[1/6] Stopping stuck processes..."
echo "---------------------------------"
pkill -9 apt 2>/dev/null || true
pkill -9 apt-get 2>/dev/null || true
pkill -9 dpkg 2>/dev/null || true
sleep 2
echo "✅ Processes stopped"

# Step 2: Remove lock files
echo ""
echo "[2/6] Removing lock files..."
echo "----------------------------"
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/lib/dpkg/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/apt/lists/lock
echo "✅ Lock files removed"

# Step 3: Fix dpkg configuration
echo ""
echo "[3/6] Fixing dpkg configuration..."
echo "----------------------------------"
dpkg --configure -a || {
    echo "⚠️  dpkg configure failed, trying to fix..."
    apt-get update --fix-missing
    dpkg --configure -a
}
echo "✅ Dpkg configured"

# Step 4: Update apt cache
echo ""
echo "[4/6] Updating apt cache..."
echo "---------------------------"
apt-get update || {
    echo "⚠️  Update failed, trying again after cleanup..."
    apt-get clean
    apt-get update
}
echo "✅ Apt cache updated"

# Step 5: Install dependencies (skip upgrade to avoid lock)
echo ""
echo "[5/6] Installing dependencies..."
echo "--------------------------------"
apt-get install -y --fix-broken \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    git \
    curl \
    wget \
    nginx \
    certbot \
    python3-certbot-nginx \
    ufw \
    htop \
    net-tools \
    || {
    echo "⚠️  Some packages failed, trying individually..."
    apt-get install -y python3 python3-pip python3-venv
    apt-get install -y build-essential libssl-dev libffi-dev python3-dev
    apt-get install -y git curl wget nginx certbot python3-certbot-nginx ufw
}
echo "✅ Dependencies installed"

# Step 6: Continue with deployment setup
echo ""
echo "[6/6] Setting up Python environment..."
echo "--------------------------------------"
cd /opt/mt5-api-bridge

# Create venv if it doesn't exist
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install Python dependencies
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    pip install mt5linux>=0.1.9 || echo "⚠️  mt5linux installation failed"
else
    echo "⚠️  requirements.txt not found, installing basics..."
    pip install fastapi uvicorn supabase python-dotenv httpx pydantic PyJWT mt5linux
fi

echo "✅ Python environment ready"

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    echo ""
    echo "⚙️  Creating .env file..."
    cat > .env <<'EOF'
# Supabase Authentication
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M

# Server Configuration
PORT=8001
HOST=0.0.0.0

# CORS Origins
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000

# Domain
DOMAIN=trade.trainflow.dev

# Logging
LOG_LEVEL=INFO
EOF
    echo "✅ .env file created"
fi

# Create systemd service
echo ""
echo "⚙️  Creating systemd service..."
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
echo "✅ Systemd service created"

echo ""
echo "=========================================="
echo "✅ Fix and Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo "   1. Start the service: systemctl start mt5-api"
echo "   2. Check status: systemctl status mt5-api"
echo "   3. View logs: journalctl -u mt5-api -f"
echo "   4. Test: curl http://localhost:8001/health"
echo ""
echo "🔧 To configure Nginx and SSL, run:"
echo "   ./deploy_vps.sh"
echo ""

