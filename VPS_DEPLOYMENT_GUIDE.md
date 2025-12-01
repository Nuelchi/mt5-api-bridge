# 🚀 MT5 API Bridge - Complete VPS Deployment Guide

## Starting from scratch? Follow this guide step-by-step!

This guide assumes you're starting fresh and will walk you through:
1. ✅ Cleanup of old installations
2. ✅ System preparation
3. ✅ Code deployment
4. ✅ Service configuration
5. ✅ Verification & testing

---

## 📋 Prerequisites

- VPS IP: `147.182.206.223`
- SSH access as root
- Domain configured: `trade.trainflow.dev` (points to VPS IP)
- GitHub repository: `https://github.com/Nuelchi/mt5-api-bridge.git`

---

## 🧹 Phase 1: Cleanup & Preparation

### Step 1: SSH into VPS

```bash
ssh root@147.182.206.223
```

### Step 2: Stop All Services (Clean Shutdown)

```bash
echo "🛑 Stopping all services..."
systemctl stop mt5-api 2>/dev/null || echo "   (mt5-api not running)"
systemctl stop nginx 2>/dev/null || echo "   (nginx not running)"
docker stop mt5 2>/dev/null || echo "   (docker mt5 not running)"
docker rm mt5 2>/dev/null || echo "   (docker mt5 container not found)"
```

### Step 3: Remove Systemd Services

```bash
echo "🗑️  Removing systemd services..."
systemctl disable mt5-api 2>/dev/null || true
rm -f /etc/systemd/system/mt5-api.service
systemctl daemon-reload
echo "✅ Services removed"
```

### Step 4: Clean Up Old Directories

```bash
echo "🧹 Cleaning up old directories..."
rm -rf /opt/mt5-api-bridge
rm -rf /opt/MetaTrader5-Docker
rm -rf /opt/mt5
rm -rf /home/mt5 2>/dev/null || true
rm -rf /var/www/mt5 2>/dev/null || true
echo "✅ Directories cleaned"
```

### Step 5: Clean Up Python Environments & Cache

```bash
echo "🐍 Cleaning Python cache..."
rm -rf ~/.cache/pip
rm -rf /opt/*/venv 2>/dev/null || true
echo "✅ Python cache cleaned"
```

### Step 6: Verify Cleanup

```bash
echo "🔍 Verifying cleanup..."
ls -la /opt/ | grep -E "mt5|MetaTrader" || echo "   ✅ No MT5 directories found"
systemctl list-units | grep mt5 || echo "   ✅ No MT5 services found"
echo "✅ Cleanup verification complete"
```

---

## 📦 Phase 2: System Update & Dependencies

### Step 1: Update System Packages

```bash
echo "📦 Updating system packages..."
apt update && apt upgrade -y
echo "✅ System updated"
```

### Step 2: Install Required Dependencies

```bash
echo "📦 Installing dependencies..."
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
```

### Step 3: Verify Python Version

```bash
python3 --version
# Should show Python 3.8 or higher
```

---

## 📥 Phase 3: Code Deployment

### Step 1: Create Application Directory

```bash
echo "📁 Creating application directory..."
mkdir -p /opt/mt5-api-bridge
cd /opt/mt5-api-bridge
echo "✅ Directory created: $(pwd)"
```

### Step 2: Clone Repository

```bash
echo "📥 Cloning repository..."
git clone https://github.com/Nuelchi/mt5-api-bridge.git .
# OR if repository already exists at .:
# git pull origin main

echo "✅ Repository cloned"
```

### Step 3: Verify Files

```bash
echo "🔍 Verifying files..."
ls -la | head -20
# Should see: mt5_api_bridge.py, requirements.txt, etc.
```

---

## 🐍 Phase 4: Python Environment Setup

### Step 1: Create Virtual Environment

```bash
echo "🐍 Creating Python virtual environment..."
cd /opt/mt5-api-bridge
python3 -m venv venv
source venv/bin/activate
echo "✅ Virtual environment created and activated"
```

### Step 2: Upgrade Pip

```bash
echo "📦 Upgrading pip..."
pip install --upgrade pip setuptools wheel
echo "✅ Pip upgraded"
```

### Step 3: Install Python Dependencies

```bash
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt
echo "✅ Python dependencies installed"
```

### Step 4: Install MT5 Library

```bash
echo "🔧 Installing MT5 library (mt5linux)..."
pip install mt5linux>=0.1.9
echo "✅ MT5 library installed"
```

### Step 5: Verify Installation

```bash
echo "🧪 Verifying Python installation..."
python3 -c "import fastapi; import uvicorn; import mt5linux; print('✅ All imports successful')"
```

---

## ⚙️ Phase 5: Environment Configuration

### Step 1: Create .env File

```bash
echo "⚙️  Creating .env file..."
cd /opt/mt5-api-bridge
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
```

### Step 2: Add Additional Environment Variables (if needed)

```bash
echo "📝 Checking for additional environment variables..."
echo ""
echo "⚠️  IMPORTANT: You may need to add these if using multi-user accounts:"
echo ""
echo "   # Supabase Service Role Key (for backend operations)"
echo "   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here"
echo ""
echo "   # Trainflow Backend (for encryption)"
echo "   TRAINFLOW_BACKEND_URL=https://trainflow-backend-1-135k.onrender.com"
echo "   TRAINFLOW_SERVICE_KEY=your_service_key_here"
echo ""
read -p "Do you want to edit .env now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    nano .env
fi
```

---

## 🧪 Phase 6: MT5 Connection Testing

### Step 1: Test MT5 Connection

```bash
echo "🧪 Testing MT5 connection..."
cd /opt/mt5-api-bridge
source venv/bin/activate
python3 test_mt5_connection.py
```

**Expected output:**
```
✅ Login successful!
📊 Account Information:
   Login: 5042856355
   Server: MetaQuotes-Demo
   Balance: [your balance]
```

**If it fails:**
- Check internet connection
- Verify MT5 credentials in test file
- Try manual connection (see troubleshooting section)

---

## 🚀 Phase 7: Service Configuration

### Step 1: Create Systemd Service

```bash
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

echo "✅ Systemd service file created"
```

### Step 2: Enable and Start Service

```bash
echo "🔄 Enabling and starting service..."
systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api

# Wait a moment for service to start
sleep 3

echo "✅ Service enabled and started"
```

### Step 3: Check Service Status

```bash
echo "📊 Checking service status..."
systemctl status mt5-api --no-pager -l

# Check if running
if systemctl is-active --quiet mt5-api; then
    echo "✅ Service is running!"
else
    echo "❌ Service failed to start"
    echo "📋 Checking logs..."
    journalctl -u mt5-api -n 50 --no-pager
fi
```

---

## 🌐 Phase 8: Nginx & SSL Configuration

### Option A: Use Deployment Script (Recommended)

```bash
cd /opt/mt5-api-bridge
chmod +x deploy_vps.sh
./deploy_vps.sh
# When prompted:
# - Enter domain: trade.trainflow.dev
# - Choose 'y' for Nginx
# - Choose 'y' for SSL
```

### Option B: Manual Nginx Setup

#### Step 1: Configure Nginx

```bash
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/mt5-api <<'EOF'
server {
    listen 80;
    server_name trade.trainflow.dev;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name trade.trainflow.dev;

    # SSL Configuration (will be added by certbot)
    # ssl_certificate /etc/letsencrypt/live/trade.trainflow.dev/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/trade.trainflow.dev/privkey.pem;

    # Proxy to FastAPI
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/mt5-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test configuration
nginx -t

echo "✅ Nginx configured"
```

#### Step 2: Set Up SSL Certificate

```bash
echo "🔒 Setting up SSL certificate..."
certbot --nginx -d trade.trainflow.dev --non-interactive --agree-tos \
    --email admin@trainflow.dev --redirect

echo "✅ SSL certificate configured"
```

#### Step 3: Restart Nginx

```bash
systemctl restart nginx
systemctl status nginx --no-pager
```

---

## 🔥 Phase 9: Firewall Configuration

### Step 1: Configure UFW Firewall

```bash
echo "🔥 Configuring firewall..."
ufw --force enable
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 8001/tcp  # API (internal)

# Show status
ufw status verbose

echo "✅ Firewall configured"
```

---

## ✅ Phase 10: Verification & Testing

### Step 1: Verify Services

```bash
echo "📊 Verifying all services..."
echo ""
echo "1. MT5 API Service:"
systemctl is-active mt5-api && echo "   ✅ Running" || echo "   ❌ Not running"

echo ""
echo "2. Nginx:"
systemctl is-active nginx && echo "   ✅ Running" || echo "   ❌ Not running"

echo ""
echo "3. Ports:"
netstat -tlnp | grep -E ":(8001|80|443) " || ss -tlnp | grep -E ":(8001|80|443) "

echo ""
echo "✅ Service verification complete"
```

### Step 2: Test Health Endpoint (Local)

```bash
echo "🧪 Testing health endpoint (local)..."
curl -s http://localhost:8001/health | python3 -m json.tool || curl -s http://localhost:8001/health
```

**Expected output:**
```json
{
  "status": "healthy",
  "mt5_available": true,
  "mt5_connected": true,
  ...
}
```

### Step 3: Test Health Endpoint (Public HTTP)

```bash
echo "🧪 Testing health endpoint (HTTP)..."
curl -s http://trade.trainflow.dev/health | python3 -m json.tool || curl -s http://trade.trainflow.dev/health
```

### Step 4: Test Health Endpoint (Public HTTPS)

```bash
echo "🧪 Testing health endpoint (HTTPS)..."
curl -s https://trade.trainflow.dev/health | python3 -m json.tool || curl -s https://trade.trainflow.dev/health
```

### Step 5: Test API Documentation

```bash
echo "📚 Opening API documentation..."
echo "   Swagger UI: https://trade.trainflow.dev/docs"
echo "   ReDoc: https://trade.trainflow.dev/redoc"
```

### Step 6: View Logs

```bash
echo "📋 Viewing recent logs..."
journalctl -u mt5-api -n 30 --no-pager
```

---

## 🎯 Quick Verification Checklist

Run these commands to verify everything is working:

```bash
# 1. Service status
systemctl status mt5-api

# 2. Health check
curl https://trade.trainflow.dev/health

# 3. Service logs
journalctl -u mt5-api -f

# 4. Port status
ss -tlnp | grep -E ":(8001|80|443)"

# 5. Nginx status
systemctl status nginx

# 6. SSL certificate
certbot certificates
```

---

## 🆘 Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl -u mt5-api -n 100 --no-pager

# Check Python environment
cd /opt/mt5-api-bridge
source venv/bin/activate
python3 --version
which python3

# Test manually
uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
```

### MT5 Connection Fails

```bash
# Test connection manually
cd /opt/mt5-api-bridge
source venv/bin/activate
python3 test_mt5_connection.py

# Check MT5 library
python3 -c "import mt5linux; print('MT5 library imported successfully')"
```

### Port Already in Use

```bash
# Find process using port 8001
lsof -i :8001 || netstat -tlnp | grep 8001

# Kill process if needed
kill -9 <PID>
```

### Nginx Issues

```bash
# Test configuration
nginx -t

# Check error logs
tail -f /var/log/nginx/error.log

# Restart nginx
systemctl restart nginx
```

### SSL Certificate Issues

```bash
# Check certificates
certbot certificates

# Renew certificate (if expired)
certbot renew

# Force renew
certbot renew --force-renewal
```

---

## 📋 Post-Deployment Tasks

1. **Backup .env file**
   ```bash
   cp /opt/mt5-api-bridge/.env /opt/mt5-api-bridge/.env.backup
   ```

2. **Set up log rotation** (optional)
   ```bash
   # Logs are managed by systemd/journalctl
   journalctl --vacuum-time=7d
   ```

3. **Monitor service**
   ```bash
   # Watch logs in real-time
   journalctl -u mt5-api -f
   ```

4. **Set up monitoring** (optional)
   - Monitor health endpoint: `https://trade.trainflow.dev/health`
   - Set up alerts for service failures

---

## 🎉 Deployment Complete!

Your MT5 API Bridge should now be running at:
- **Production URL:** https://trade.trainflow.dev
- **API Docs:** https://trade.trainflow.dev/docs
- **Health Check:** https://trade.trainflow.dev/health

### Quick Commands Reference

```bash
# Service management
systemctl status mt5-api
systemctl restart mt5-api
systemctl stop mt5-api
systemctl start mt5-api

# View logs
journalctl -u mt5-api -f
journalctl -u mt5-api -n 50

# Test API
curl https://trade.trainflow.dev/health
curl -H "Authorization: Bearer YOUR_TOKEN" https://trade.trainflow.dev/api/v1/account/info

# Environment
cd /opt/mt5-api-bridge
source venv/bin/activate
```

---

## 📚 Additional Resources

- **Main README:** See `README.md` for API documentation
- **Deployment Steps:** See `DEPLOYMENT_STEPS.md` for alternative deployment
- **Reset Guide:** See `RESET_GUIDE.md` if you need to start over
- **SSH Commands:** See `SSH_COMMANDS.md` for quick commands

---

**Last Updated:** $(date)
**Version:** 1.0.0

