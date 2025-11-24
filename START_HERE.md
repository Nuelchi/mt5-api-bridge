# 🚀 Start Here - VPS Deployment

## Quick Start (Copy & Paste)

**SSH into your VPS and run these commands:**

```bash
# 1. SSH into VPS
ssh root@147.182.206.223

# 2. Clean up old directories
rm -rf /opt/mt5-api-bridge /opt/MetaTrader5-Docker /opt/mt5

# 3. Update system and install dependencies
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx

# 4. Clone repository
cd /opt
git clone https://github.com/Nuelchi/mt5-api-bridge.git mt5-api-bridge
cd mt5-api-bridge

# 5. Set up Python environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install mt5linux

# 6. Create .env file
cat > .env <<'EOF'
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M
PORT=8001
HOST=0.0.0.0
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000
DOMAIN=trade.trainflow.dev
LOG_LEVEL=INFO
EOF

# 7. Test MT5 connection
python3 test_mt5_connection.py

# 8. Create systemd service
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

# 9. Verify
systemctl status mt5-api
curl http://localhost:8001/health
```

## ✅ What This Does

1. ✅ Cleans up old directories
2. ✅ Updates system packages
3. ✅ Clones your GitHub repo
4. ✅ Sets up Python environment
5. ✅ Installs MT5 (mt5linux)
6. ✅ Creates .env with your credentials
7. ✅ Tests MT5 connection
8. ✅ Creates and starts systemd service
9. ✅ Verifies everything works

## 🔐 MT5 Credentials

The test script will use:
- Server: MetaQuotes-Demo
- Login: 5042856355
- Password: V!QzRxQ7

## 📋 Next Steps After Deployment

1. **Test JWT Authentication:**
   ```bash
   python3 test_jwt_auth.py
   ```

2. **Configure Nginx (for SSL):**
   ```bash
   ./deploy_vps.sh
   # Enter: trade.trainflow.dev
   # Choose 'y' for SSL
   ```

3. **Test API:**
   ```bash
   curl https://trade.trainflow.dev/health
   ```

## 🆘 Need Help?

- Check logs: `journalctl -u mt5-api -f`
- Service status: `systemctl status mt5-api`
- See `SSH_COMMANDS.md` for detailed steps

