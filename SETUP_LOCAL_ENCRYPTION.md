# Setup Local Encryption Fallback

The MT5 API Bridge now supports local encryption as a fallback when the backend encryption service is unavailable.

## Steps

### 1. Get the Encryption Key from Backend

You need to get the `MT5_ENCRYPTION_KEY` from your backend environment. This should be the same key used in your `trainflow-backend-c` service.

**Option A: Check Backend .env File**
```bash
# On your backend server or locally
grep MT5_ENCRYPTION_KEY /path/to/trainflow-backend-c/.env
```

**Option B: Check Render.com Environment Variables**
- Go to your Render.com dashboard
- Select the `trainflow-backend` service
- Go to Environment tab
- Look for `MT5_ENCRYPTION_KEY`

### 2. Add Encryption Key to MT5 Bridge

Add the key to your `.env` file:

```bash
cd /opt/mt5-api-bridge

# Edit .env file
nano .env

# Add this line (replace with your actual key):
MT5_ENCRYPTION_KEY=your_encryption_key_here
```

### 3. Install Cryptography Package

```bash
cd /opt/mt5-api-bridge
source venv/bin/activate
pip install cryptography>=41.0.0
```

### 4. Restart Service

```bash
systemctl restart mt5-api
systemctl status mt5-api
```

### 5. Test

Try connecting an account again - it should now use local encryption as a fallback if the backend is unavailable.

## How It Works

The encryption service tries methods in this order:

1. **Backend API** (`https://trainflow-backend-1-135k.onrender.com/api/v1/accounts/encrypt`)
   - Uses `TRAINFLOW_SERVICE_KEY` for authentication
   - Times out after 60s with retries

2. **Supabase RPC** (`encrypt_password` function)
   - Falls back if backend unavailable
   - Requires RPC function to exist in Supabase

3. **Local Encryption** (Fernet)
   - Final fallback
   - Uses `MT5_ENCRYPTION_KEY` from environment
   - Only works if key matches backend's key

## Troubleshooting

**If encryption still fails:**
- Check that `MT5_ENCRYPTION_KEY` is set correctly
- Verify the key matches your backend's key
- Check logs: `journalctl -u mt5-api -n 50 | grep -i encrypt`
- Ensure cryptography package is installed: `pip list | grep cryptography`

