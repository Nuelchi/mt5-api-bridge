# 🚀 Quick Deploy & Test - Compiler Integration

## On VPS (ssh root@147.182.206.223)

```bash
# Deploy
cd /opt/mt5-api-bridge
chmod +x DEPLOY_COMPILER.sh
./DEPLOY_COMPILER.sh
```

That's it! The script will:
1. Pull latest code ✅
2. Check Docker is running ✅
3. Set up compilation environment ✅
4. Restart API ✅
5. Verify health ✅

---

## Test Compilation (Simple cURL Test)

```bash
# Get fresh token from: https://dashboard.trainflow.dev
TOKEN="YOUR_FRESH_TOKEN_HERE"

# Read sample EA
EA_CODE=$(cat sample_eas/MA_Crossover_Basic.mq5)

# Test compile
curl -X POST https://trade.trainflow.dev/api/v1/algorithms/compile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "'"$EA_CODE"'",
    "filename": "TestEA.mq5",
    "validate_only": false
  }' | python3 -m json.tool
```

---

## Test with Python Script (Better)

```bash
cd /opt/mt5-api-bridge

# Update token in test_compiler.py first
nano test_compiler.py  # Update TOKEN variable

# Run tests
python3 test_compiler.py
```

---

## Expected Results ✅

**If Working:**
```json
{
  "success": true,
  "filename": "TestEA.mq5",
  "compiled_path": "/tmp/mql_compile/TestEA.ex5",
  "errors": [],
  "warnings": [],
  "compile_time": 2.5
}
```

**If Compilation Failed:**
```json
{
  "success": false,
  "errors": ["error 149: 'something' - syntax error"],
  "warnings": []
}
```

---

## Rollback if Needed ⚠️

```bash
cd /opt/mt5-api-bridge
git reset --hard v1.1.0-stable
systemctl restart mt5-api

# Verify
curl http://localhost:8000/health
python3 test_login_and_trading.py
```

---

## What's New

**New Endpoints:**
- `POST /api/v1/algorithms/compile` - Compile MQL5/MQL4 code
- `POST /api/v1/algorithms/compile-and-deploy` - Compile & deploy to MT5

**Features:**
- ✅ Validates MQL5 syntax
- ✅ Compiles in Docker MT5 container  
- ✅ Deploys to MT5 Experts folder
- ✅ User-specific folders (Trainflow_{user_id})
- ✅ Detailed error reporting
- ✅ Supports AI-generated EA code

**Your Sample EA:**
- Located: `sample_eas/MA_Crossover_Basic.mq5`
- Ready to compile and test!

---

## Troubleshooting

**1. Docker not running:**
```bash
docker start mt5
sleep 10
./DEPLOY_COMPILER.sh
```

**2. Permission denied:**
```bash
chmod +x DEPLOY_COMPILER.sh test_compiler.py
```

**3. API won't start:**
```bash
# Check logs
journalctl -u mt5-api -n 50

# If mql_compiler import fails, rollback
git reset --hard v1.1.0-stable
```

**4. Token expired:**
- Get fresh token from https://dashboard.trainflow.dev
- Token lasts 1 hour

---

## Next Steps After Testing

If compiler works:
1. ✅ Update frontend to use new endpoints
2. ✅ Build EA marketplace UI
3. ✅ Add EA parameter customization
4. ✅ Implement multi-user MT5 accounts

If needs fixes:
1. ⚠️ Rollback immediately
2. ⚠️ Report errors
3. ⚠️ Fix and redeploy

---

**Ready? Run the deploy script!** 🚀

