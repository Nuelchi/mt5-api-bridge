# MT5 API Bridge - Production Deployment Environment

## ✅ Environment Variables Configured

All production environment variables have been set up in `.env.production`.

### Current Configuration

```bash
# Supabase Authentication
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M

# Server
PORT=8001
HOST=0.0.0.0

# CORS
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000

# Domain
DOMAIN=trade.trainflow.dev

# Logging
LOG_LEVEL=INFO
```

## 📋 Deployment Checklist

### Pre-Deployment

- [x] Supabase credentials configured
- [x] Server port configured (8001)
- [x] CORS origins set (dashboard, traintrading, localhost)
- [x] Domain configured (trade.trainflow.dev)
- [x] Logging level set (INFO)

### What We Have

✅ **Supabase Authentication**
- URL: `https://kgfzbkwyepchbysaysky.supabase.co`
- Anon Key: Configured
- JWT verification: Ready

✅ **Server Configuration**
- Port: `8001`
- Host: `0.0.0.0` (all interfaces)
- CORS: Configured for your domains

✅ **Domain**
- Subdomain: `trade.trainflow.dev`
- IP: `147.182.206.223` (from your DNS records)

### What We Need (Optional)

1. **Test JWT Token** (for testing only)
   - Get from browser console after login
   - `localStorage.getItem('supabase.auth.token')`
   - Add to `.env.production` as `TEST_JWT_TOKEN=...`

2. **MT5 Account Credentials** (when connecting)
   - Login number
   - Password
   - Server name
   - These will be sent via API, not stored in .env

## 🚀 Deployment Steps

### 1. Upload Files to VPS

```bash
# From your local machine
scp -r mt5-api-bridge/* root@147.182.206.223:/opt/mt5-api-bridge/
```

### 2. SSH into VPS

```bash
ssh root@147.182.206.223
```

### 3. Set Up Environment

```bash
cd /opt/mt5-api-bridge

# Copy production env file
cp .env.production .env

# Verify environment variables
cat .env
```

### 4. Test JWT Authentication

```bash
# Install test dependencies (if not already installed)
pip3 install python-dotenv httpx

# Test JWT authentication
python3 test_jwt_auth.py
```

**Expected output:**
```
✅ Supabase client created successfully
✅ JWT token verified successfully!
🎯 Overall: JWT Authentication is WORKING ✅
```

### 5. Run Deployment Script

```bash
chmod +x deploy_vps.sh
sudo ./deploy_vps.sh
```

The script will:
- Install system dependencies
- Create Python virtual environment
- Install Python packages
- Create systemd service
- Configure Nginx (if you choose)
- Set up SSL certificate (if you choose)

### 6. Verify Deployment

```bash
# Check service status
systemctl status mt5-api

# Check health endpoint
curl http://localhost:8001/health

# Check logs
journalctl -u mt5-api -f
```

### 7. Test API Endpoints

```bash
# Health check (no auth needed)
curl https://trade.trainflow.dev/health

# Authenticated endpoint (need JWT token)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://trade.trainflow.dev/api/v1/account/info
```

## 🔐 Security Notes

1. **Environment File**: `.env.production` contains sensitive data
   - Do NOT commit to git
   - Keep secure on VPS
   - Use file permissions: `chmod 600 .env`

2. **JWT Tokens**: 
   - Tokens are verified via Supabase
   - No tokens stored in .env (only for testing)
   - Frontend sends tokens in Authorization header

3. **CORS**: 
   - Only configured domains can access API
   - Production: `dashboard.trainflow.dev`, `traintrading.trainflow.dev`
   - Development: `localhost:3000`

## 📊 Monitoring

### Service Status
```bash
systemctl status mt5-api
```

### View Logs
```bash
# Follow logs
journalctl -u mt5-api -f

# Last 50 lines
journalctl -u mt5-api -n 50

# Errors only
journalctl -u mt5-api -p err
```

### Health Check
```bash
curl https://trade.trainflow.dev/health
```

## 🆘 Troubleshooting

### Service Won't Start
```bash
# Check logs
journalctl -u mt5-api -n 50

# Check if port is in use
netstat -tulpn | grep 8001

# Restart service
systemctl restart mt5-api
```

### JWT Authentication Fails
```bash
# Test Supabase connection
python3 test_jwt_auth.py

# Verify .env file
cat .env | grep SUPABASE
```

### SSL Certificate Issues
```bash
# Check certificate
certbot certificates

# Renew if needed
certbot renew
```

## ✅ Ready to Deploy!

All environment variables are configured. You can now:

1. Upload files to VPS
2. Run deployment script
3. Test JWT authentication
4. Verify API endpoints

**Everything is ready!** 🚀



