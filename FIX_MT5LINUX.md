# Fix: mt5linux Version Error

## ❌ Error You Got

```
ERROR: Could not find a version that satisfies the requirement mt5linux>=1.0.0
ERROR: No matching distribution found for mt5linux>=1.0.0
```

## ✅ Solution

The latest version of `mt5linux` is `0.1.9`, not `1.0.0`.

### Quick Fix (On Your VPS)

```bash
cd /opt/mt5-api-bridge
source venv/bin/activate

# Install correct version
pip install mt5linux>=0.1.9

# Or just install latest
pip install mt5linux
```

### Or Update requirements.txt

The requirements.txt has been fixed. Pull the latest:

```bash
cd /opt/mt5-api-bridge
git pull
pip install -r requirements.txt
```

## ✅ Continue Deployment

After fixing mt5linux, continue with:

```bash
# Install mt5linux (correct version)
pip install mt5linux

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



