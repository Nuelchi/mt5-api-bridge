#!/bin/bash
# Complete VPS Deployment Script
# Run this AFTER cleanup to deploy the MT5 API Bridge
# Usage: bash VPS_DEPLOYMENT.sh

set -e

echo "🚀 MT5 API Bridge - Complete VPS Deployment"
echo "============================================"
echo ""
echo "This script will:"
echo "  1. Update system packages"
echo "  2. Install dependencies"
echo "  3. Clone repository"
echo "  4. Set up Python environment"
echo "  5. Configure environment variables"
echo "  6. Test MT5 connection"
echo "  7. Create and start systemd service"
echo "  8. Configure Nginx (optional)"
echo "  9. Set up SSL (optional)"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo bash VPS_DEPLOYMENT.sh)"
    exit 1
fi

# Step 1: Update system
echo ""
echo "[1/9] Updating system packages..."
echo "---------------------------------"
apt update && apt upgrade -y
echo "✅ System updated"

# Step 2: Install dependencies
echo ""
echo "[2/9] Installing dependencies..."
echo "--------------------------------"
apt install -y \
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
    net-tools

echo "✅ Dependencies installed"

# Step 3: Verify Python
echo ""
echo "[3/9] Verifying Python installation..."
echo "--------------------------------------"
PYTHON_VERSION=$(python3 --version)
echo "   Python version: $PYTHON_VERSION"
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found!"
    exit 1
fi
echo "✅ Python verified"

# Step 4: Create and clone repository
echo ""
echo "[4/9] Setting up repository..."
echo "-------------------------------"
APP_DIR="/opt/mt5-api-bridge"
mkdir -p $APP_DIR
cd $APP_DIR

if [ -d ".git" ]; then
    echo "   Repository exists, pulling latest..."
    git pull
else
    echo "   Cloning repository..."
    git clone https://github.com/Nuelchi/mt5-api-bridge.git .
fi

echo "✅ Repository ready"

# Step 5: Set up Python environment
echo ""
echo "[5/9] Setting up Python environment..."
echo "--------------------------------------"
echo "   Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "   Upgrading pip..."
pip install --upgrade pip setuptools wheel

echo "   Installing dependencies..."
pip install -r requirements.txt

echo "   Installing MT5 library..."
pip install mt5linux>=0.1.9 || {
    echo "⚠️  mt5linux installation failed, but continuing..."
}

echo "✅ Python environment ready"

# Step 6: Configure environment variables
echo ""
echo "[6/9] Configuring environment variables..."
echo "------------------------------------------"
if [ ! -f ".env" ]; then
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
else
    echo "⚠️  .env file already exists, skipping..."
fi

echo ""
echo "📝 Optional: Add additional environment variables?"
echo "   - SUPABASE_SERVICE_ROLE_KEY"
echo "   - TRAINFLOW_BACKEND_URL"
echo "   - TRAINFLOW_SERVICE_KEY"
read -p "Edit .env file now? (y/n): " edit_env
if [[ $edit_env =~ ^[Yy]$ ]]; then
    nano .env
fi

# Step 7: Test MT5 connection
echo ""
echo "[7/9] Testing MT5 connection..."
echo "-------------------------------"
source venv/bin/activate
if python3 test_mt5_connection.py; then
    echo "✅ MT5 connection test passed"
else
    echo "⚠️  MT5 connection test failed, but continuing..."
    echo "   You may need to configure MT5 credentials manually"
fi

# Step 8: Create and start systemd service
echo ""
echo "[8/9] Setting up systemd service..."
echo "-----------------------------------"
cat > /etc/systemd/system/mt5-api.service <<EOF
[Unit]
Description=MT5 API Bridge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api

sleep 3

if systemctl is-active --quiet mt5-api; then
    echo "✅ Service is running!"
else
    echo "❌ Service failed to start"
    echo "📋 Checking logs..."
    journalctl -u mt5-api -n 30 --no-pager
    echo ""
    echo "⚠️  Service failed, but continuing with next steps..."
fi

# Step 9: Configure Nginx and SSL
echo ""
echo "[9/9] Configuring Nginx and SSL..."
echo "----------------------------------"
read -p "Configure Nginx reverse proxy? (y/n): " setup_nginx
if [[ $setup_nginx =~ ^[Yy]$ ]]; then
    DOMAIN="trade.trainflow.dev"
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/mt5-api <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/mt5-api /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    if nginx -t; then
        systemctl restart nginx
        echo "✅ Nginx configured"
        
        # Set up SSL
        read -p "Set up SSL certificate with Let's Encrypt? (y/n): " setup_ssl
        if [[ $setup_ssl =~ ^[Yy]$ ]]; then
            read -p "Enter email for SSL certificate: " ssl_email
            certbot --nginx -d $DOMAIN --non-interactive --agree-tos \
                --email ${ssl_email:-admin@trainflow.dev} --redirect || {
                echo "⚠️  SSL setup failed, but continuing..."
            }
            echo "✅ SSL configured"
        fi
    else
        echo "❌ Nginx configuration test failed"
    fi
else
    echo "⚠️  Skipping Nginx configuration"
fi

# Configure firewall
echo ""
read -p "Configure firewall (UFW)? (y/n): " setup_firewall
if [[ $setup_firewall =~ ^[Yy]$ ]]; then
    ufw --force enable
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8001/tcp
    echo "✅ Firewall configured"
fi

# Final summary
echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "📊 Service Status:"
systemctl is-active mt5-api && echo "   ✅ MT5 API: Running" || echo "   ❌ MT5 API: Not running"
systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ⚠️  Nginx: Not running"

echo ""
echo "🧪 Test the API:"
echo "   Local:  curl http://localhost:8001/health"
echo "   Public: curl https://trade.trainflow.dev/health"

echo ""
echo "📋 Useful Commands:"
echo "   Status:    systemctl status mt5-api"
echo "   Logs:      journalctl -u mt5-api -f"
echo "   Restart:   systemctl restart mt5-api"
echo "   Stop:      systemctl stop mt5-api"
echo "   Start:     systemctl start mt5-api"

echo ""
echo "📚 Documentation:"
echo "   - VPS_DEPLOYMENT_GUIDE.md (complete guide)"
echo "   - README.md (API documentation)"
echo ""
echo "🎉 Setup complete! Your MT5 API Bridge should be running."
echo ""

