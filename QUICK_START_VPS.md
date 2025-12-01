# 🚀 Quick Start: VPS Deployment (From Scratch)

This is your **step-by-step guide** to deploy the MT5 API Bridge on your VPS from scratch.

---

## 📋 Pre-Flight Checklist

Before starting, make sure you have:
- ✅ SSH access to VPS: `root@147.182.206.223`
- ✅ Domain configured: `trade.trainflow.dev` (points to VPS IP)
- ✅ GitHub repository access: `https://github.com/Nuelchi/mt5-api-bridge.git`

---

## 🎯 Quick Deploy (Automated)

### Option 1: Full Automated Deploy (Recommended)

Run these two scripts in order:

```bash
# Step 1: SSH into VPS
ssh root@147.182.206.223

# Step 2: Download cleanup script
cd /tmp
curl -o CLEANUP_VPS.sh https://raw.githubusercontent.com/Nuelchi/mt5-api-bridge/main/CLEANUP_VPS.sh
chmod +x CLEANUP_VPS.sh
bash CLEANUP_VPS.sh

# Step 3: Download deployment script
cd /tmp
curl -o VPS_DEPLOYMENT.sh https://raw.githubusercontent.com/Nuelchi/mt5-api-bridge/main/VPS_DEPLOYMENT.sh
chmod +x VPS_DEPLOYMENT.sh
bash VPS_DEPLOYMENT.sh
```

### Option 2: Use Existing Scripts in Repository

If you've already cloned the repository:

```bash
# Step 1: SSH into VPS
ssh root@147.182.206.223

# Step 2: Clone repository
cd /opt
git clone https://github.com/Nuelchi/mt5-api-bridge.git mt5-api-bridge
cd mt5-api-bridge

# Step 3: Run cleanup
chmod +x CLEANUP_VPS.sh
bash CLEANUP_VPS.sh

# Step 4: Run deployment
chmod +x VPS_DEPLOYMENT.sh
bash VPS_DEPLOYMENT.sh
```

---

## 📝 Manual Step-by-Step (If Scripts Fail)

### Phase 1: Cleanup

```bash
# SSH into VPS
ssh root@147.182.206.223

# Stop services
systemctl stop mt5-api 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
docker stop mt5 2>/dev/null || true

# Remove services
systemctl disable mt5-api 2>/dev/null || true
rm -f /etc/systemd/system/mt5-api.service
systemctl daemon-reload

# Remove directories
rm -rf /opt/mt5-api-bridge
rm -rf /opt/MetaTrader5-Docker
rm -rf /opt/mt5

# Clean Python cache
rm -rf ~/.cache/pip
```

### Phase 2: System Setup

```bash
# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx ufw

# Verify Python
python3 --version
```

### Phase 3: Code Deployment

```bash
# Create directory and clone
mkdir -p /opt/mt5-api-bridge
cd /opt/mt5-api-bridge
git clone https://github.com/Nuelchi/mt5-api-bridge.git .

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
pip install mt5linux>=0.1.9
```

### Phase 4: Configuration

```bash
# Create .env file
cat > .env <<'EOF'
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M
PORT=8001
HOST=0.0.0.0
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000
DOMAIN=trade.trainflow.dev
LOG_LEVEL=INFO
EOF

# Test MT5 connection
python3 test_mt5_connection.py
```

### Phase 5: Service Setup

```bash
# Create systemd service
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

# Enable and start service
systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api

# Check status
systemctl status mt5-api
```

### Phase 6: Nginx & SSL

```bash
# Configure Nginx
cat > /etc/nginx/sites-available/mt5-api <<'EOF'
server {
    listen 80;
    server_name trade.trainflow.dev;

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
    }
}
EOF

ln -sf /etc/nginx/sites-available/mt5-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

# Set up SSL
certbot --nginx -d trade.trainflow.dev --non-interactive --agree-tos \
    --email admin@trainflow.dev --redirect
```

---

## ✅ Verification

After deployment, verify everything works:

```bash
# 1. Check service status
systemctl status mt5-api

# 2. Test health endpoint (local)
curl http://localhost:8001/health

# 3. Test health endpoint (public)
curl https://trade.trainflow.dev/health

# 4. View logs
journalctl -u mt5-api -f

# 5. Check ports
ss -tlnp | grep -E ":(8001|80|443)"
```

**Expected health response:**
```json
{
  "status": "healthy",
  "mt5_available": true,
  "mt5_connected": true,
  ...
}
```

---

## 🆘 Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl -u mt5-api -n 100

# Test manually
cd /opt/mt5-api-bridge
source venv/bin/activate
uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
```

### MT5 Connection Issues

```bash
# Test connection
cd /opt/mt5-api-bridge
source venv/bin/activate
python3 test_mt5_connection.py

# Check library
python3 -c "import mt5linux; print('OK')"
```

### Port Already in Use

```bash
# Find process
lsof -i :8001 || netstat -tlnp | grep 8001

# Kill if needed
kill -9 <PID>
```

### Nginx Issues

```bash
# Test config
nginx -t

# Check logs
tail -f /var/log/nginx/error.log

# Restart
systemctl restart nginx
```

---

## 📚 Additional Resources

- **Full Guide:** See `VPS_DEPLOYMENT_GUIDE.md` for detailed instructions
- **API Docs:** See `README.md` for API documentation
- **Reset Guide:** See `RESET_GUIDE.md` if you need to start over

---

## 🎉 Success!

Once deployed, your API will be available at:
- **Production URL:** https://trade.trainflow.dev
- **API Docs:** https://trade.trainflow.dev/docs
- **Health Check:** https://trade.trainflow.dev/health

### Quick Commands

```bash
# Service management
systemctl status mt5-api      # Check status
systemctl restart mt5-api     # Restart service
journalctl -u mt5-api -f      # View logs

# Test API
curl https://trade.trainflow.dev/health
```

---

**Ready to start?** Run the automated scripts or follow the manual steps above! 🚀

