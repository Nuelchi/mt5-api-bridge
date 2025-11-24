#!/bin/bash
# MT5 API Bridge VPS Deployment Script
# Run this on your Linux VPS to set up the MT5 API Bridge

set -e

echo "🚀 MT5 API Bridge VPS Deployment"
echo "================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo ./deploy_vps.sh)"
    exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install dependencies
echo "📦 Installing dependencies..."
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx

# Create application directory
APP_DIR="/opt/mt5-api-bridge"
echo "📁 Creating application directory: $APP_DIR"
mkdir -p $APP_DIR
cd $APP_DIR

# Create virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python packages
echo "📦 Installing Python packages..."
pip install --upgrade pip
pip install -r requirements.txt

# Create systemd service
echo "⚙️  Creating systemd service..."
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
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "🔄 Enabling and starting service..."
systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api

# Wait a moment for service to start
sleep 2

# Check service status
if systemctl is-active --quiet mt5-api; then
    echo "✅ Service is running!"
else
    echo "❌ Service failed to start. Check logs: journalctl -u mt5-api"
    exit 1
fi

# Configure Nginx (optional)
read -p "🌐 Configure Nginx reverse proxy? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📝 Configuring Nginx..."
    
    read -p "Enter your domain name (or press Enter to skip): " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo "⚠️  Skipping Nginx configuration"
    else
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
    }
}
EOF
        
        ln -sf /etc/nginx/sites-available/mt5-api /etc/nginx/sites-enabled/
        nginx -t && systemctl restart nginx
        
        echo "✅ Nginx configured!"
        
        # SSL setup
        read -p "🔒 Set up SSL with Let's Encrypt? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN || true
            echo "✅ SSL configured!"
        fi
    fi
fi

# Firewall configuration
read -p "🔥 Configure firewall? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v ufw &> /dev/null; then
        ufw allow 8001/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        echo "✅ Firewall configured!"
    else
        echo "⚠️  UFW not installed, skipping firewall configuration"
    fi
fi

# Summary
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Service Information:"
echo "   - Service: mt5-api"
echo "   - Status: $(systemctl is-active mt5-api)"
echo "   - Port: 8001"
echo "   - Logs: journalctl -u mt5-api -f"
echo ""
echo "🧪 Test the API:"
echo "   curl http://localhost:8001/health"
echo ""
echo "📚 Next steps:"
echo "   1. Create .env file with Supabase credentials"
echo "   2. Test JWT authentication: python3 test_jwt_auth.py"
echo "   3. View API docs: http://your-vps-ip:8001/docs"
echo ""

