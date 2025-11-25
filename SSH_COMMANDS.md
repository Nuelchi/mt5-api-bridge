# SSH Commands for VPS Deployment

## 🚀 Quick Deploy (All-in-One)

Copy and paste these commands into your VPS terminal:

```bash
# SSH into VPS
ssh root@147.182.206.223

# Download and run quick deploy script
cd /tmp
curl -o quick_deploy.sh https://raw.githubusercontent.com/Nuelchi/mt5-api-bridge/main/QUICK_DEPLOY.sh
chmod +x quick_deploy.sh
sudo bash quick_deploy.sh
```

## 📋 Manual Step-by-Step (If Quick Deploy Fails)

### 1. SSH into VPS
```bash
ssh root@147.182.206.223
```

### 2. Clean Up Old Directories
```bash
rm -rf /opt/mt5-api-bridge
rm -rf /opt/MetaTrader5-Docker
rm -rf /opt/mt5
```

### 3. Update System
```bash
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx
```

### 4. Clone Repository
```bash
cd /opt
git clone https://github.com/Nuelchi/mt5-api-bridge.git mt5-api-bridge
cd mt5-api-bridge
```

### 5. Set Up Python Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install mt5linux
```

### 6. Create .env File
```bash
cat > .env <<'EOF'
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M
PORT=8001
HOST=0.0.0.0
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000
DOMAIN=trade.trainflow.dev
LOG_LEVEL=INFO
EOF
```

### 7. Test MT5 Connection
```bash
python3 test_mt5_connection.py
```

**Expected output:**
```
✅ Login successful!
📊 Account Information:
   Login: 5042856355
   Server: MetaQuotes-Demo
```

### 8. Create Systemd Service
```bash
cat > /etc/systemd/system/mt5-api.service <<'EOF'
[Unit]
Description=MT5 API Bridge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mt5-api-bridge
Environment="PATH=/opt/mt5-api-bridge/venv/bin"
ExecStart=/opt/mt5-api-bridge/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api
```

### 9. Verify Service
```bash
# Check status
systemctl status mt5-api

# Test health endpoint
curl http://localhost:8001/health

# View logs
journalctl -u mt5-api -f
```

### 10. Configure Nginx (Optional)
```bash
cd /opt/mt5-api-bridge
chmod +x deploy_vps.sh
./deploy_vps.sh
# When prompted:
# - Enter domain: trade.trainflow.dev
# - Choose 'y' for SSL
```

## 🔐 MT5 Credentials (for test_mt5_connection.py)

The test script uses these credentials:
- Server: MetaQuotes-Demo
- Login: 5042856355
- Password: V!QzRxQ7

## ✅ Verification Commands

```bash
# Service status
systemctl status mt5-api

# Health check
curl http://localhost:8001/health

# Test with JWT token
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:8001/api/v1/account/info

# View logs
journalctl -u mt5-api -f
```

## 🆘 Troubleshooting

### Service won't start
```bash
journalctl -u mt5-api -n 50
```

### MT5 connection fails
```bash
cd /opt/mt5-api-bridge
source venv/bin/activate
python3 test_mt5_connection.py
```

### Port conflict
```bash
netstat -tulpn | grep 8001
# Kill process if needed
kill -9 <PID>
```



