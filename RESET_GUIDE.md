# MT5 Bridge VPS - Fresh Reset Guide

## 🚨 Complete Fresh Reset

Use this when you want to **completely remove everything** and start from scratch.

### Option 1: Full Reset Script (Recommended)

```bash
# SSH into your VPS
ssh root@your-vps-ip

# Navigate to the bridge directory
cd /opt/mt5-api-bridge

# Run the reset script
bash FRESH_RESET.sh
```

**What it does:**
1. ✅ Stops all services (mt5-api, nginx, docker)
2. ✅ Removes systemd service
3. ✅ Deletes `/opt/mt5-api-bridge` directory
4. ✅ Cleans up Python environments
5. ✅ Removes log files
6. ✅ Clones fresh repository
7. ✅ Sets up Python virtual environment

### Option 2: Quick Reset (Keep Code)

Use this if you just want to reset the service without removing code:

```bash
cd /opt/mt5-api-bridge
bash QUICK_FRESH_RESET.sh
```

**What it does:**
1. ✅ Stops service
2. ✅ Removes systemd service
3. ✅ Recreates Python venv
4. ✅ Pulls latest code

---

## 📋 After Reset - Setup Steps

### 1. Set Environment Variables

```bash
cd /opt/mt5-api-bridge
nano .env
```

**Required variables:**
```bash
# Supabase
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Backend (for encryption)
TRAINFLOW_BACKEND_URL=https://trainflow-backend-1-135k.onrender.com
TRAINFLOW_SERVICE_KEY=your_service_key

# Optional
LOG_LEVEL=INFO
```

### 2. Run Complete Setup

```bash
cd /opt/mt5-api-bridge
bash COMPLETE_SETUP.sh
```

Or follow manual setup:

```bash
# Install dependencies
source venv/bin/activate
pip install -r requirements.txt

# Setup systemd service
sudo cp mt5-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mt5-api
sudo systemctl start mt5-api

# Check status
sudo systemctl status mt5-api
```

### 3. Verify Installation

```bash
# Check service status
systemctl status mt5-api

# Check logs
journalctl -u mt5-api -f

# Test API
curl https://trade.trainflow.dev/health
```

---

## 🔧 Manual Reset (Step by Step)

If you prefer to do it manually:

### Step 1: Stop Services
```bash
sudo systemctl stop mt5-api
sudo systemctl disable mt5-api
sudo systemctl stop nginx
docker stop mt5 2>/dev/null || true
```

### Step 2: Remove Service
```bash
sudo rm -f /etc/systemd/system/mt5-api.service
sudo systemctl daemon-reload
```

### Step 3: Remove Installation
```bash
sudo rm -rf /opt/mt5-api-bridge
```

### Step 4: Reinstall
```bash
# Clone repository
cd /opt
git clone https://github.com/Nuelchi/mt5-api-bridge.git
cd mt5-api-bridge

# Setup Python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configure environment
nano .env  # Add your environment variables

# Setup service
sudo cp mt5-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mt5-api
sudo systemctl start mt5-api
```

---

## ⚠️ Important Notes

1. **Backup Environment Variables**: Save your `.env` file before resetting
2. **Docker Containers**: The reset script doesn't remove Docker containers by default (uncomment if needed)
3. **Nginx Config**: If you have custom Nginx config, back it up first
4. **Database**: This doesn't affect Supabase database (accounts are safe)

---

## 🐛 Troubleshooting

### Service Won't Start
```bash
# Check logs
journalctl -u mt5-api -n 50

# Check Python
cd /opt/mt5-api-bridge
source venv/bin/activate
python3 --version  # Should be 3.10 or 3.11
```

### Missing Dependencies
```bash
cd /opt/mt5-api-bridge
source venv/bin/activate
pip install -r requirements.txt --force-reinstall
```

### Permission Issues
```bash
sudo chown -R $USER:$USER /opt/mt5-api-bridge
chmod +x /opt/mt5-api-bridge/*.sh
```

---

## ✅ Verification Checklist

After reset, verify:

- [ ] Service is running: `systemctl status mt5-api`
- [ ] Health endpoint works: `curl https://trade.trainflow.dev/health`
- [ ] Logs show no errors: `journalctl -u mt5-api -n 20`
- [ ] Python environment is active: `which python3` (should show venv path)
- [ ] Environment variables are set: `cat /opt/mt5-api-bridge/.env`

---

## 🚀 Quick Commands Reference

```bash
# Full reset
cd /opt/mt5-api-bridge && bash FRESH_RESET.sh

# Quick reset
cd /opt/mt5-api-bridge && bash QUICK_FRESH_RESET.sh

# Check status
systemctl status mt5-api

# View logs
journalctl -u mt5-api -f

# Restart service
systemctl restart mt5-api

# Test API
curl https://trade.trainflow.dev/health
```

