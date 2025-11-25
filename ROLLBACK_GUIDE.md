# 🔄 Rollback Guide - Compiler Integration

If the compiler integration doesn't work, use this guide to quickly revert to the stable trading-only version.

## Quick Rollback

```bash
cd /opt/mt5-api-bridge
git fetch --tags
git reset --hard v1.1.0-stable
systemctl restart mt5-api
```

## Verify Rollback

```bash
# Check git status
git log --oneline -1

# Should show: "BACKUP: Working MT5 API Bridge - All tests passing (10/10)"

# Test API
curl http://localhost:8000/health

# Run trading tests
python3 test_login_and_trading.py
```

## What Gets Rolled Back

The rollback removes:
- ✅ MQL compiler (`mql_compiler.py`)
- ✅ Algorithm endpoints (`/api/v1/algorithms/*`)
- ✅ Test files (`test_compiler.py`)
- ✅ Sample EAs (`sample_eas/`)

**What stays:**
- ✅ All trading endpoints (working perfectly)
- ✅ JWT authentication
- ✅ Market data endpoints
- ✅ Account management

## Re-Deploy After Fixes

If you fix issues and want to try again:

```bash
cd /opt/mt5-api-bridge
git pull
chmod +x DEPLOY_COMPILER.sh
./DEPLOY_COMPILER.sh
```

## Stable Version Details

**Tag:** `v1.1.0-stable`  
**Status:** All tests passing (10/10)  
**Features:**
- Account info ✅
- Market data ✅
- Place trades (buy/sell) ✅
- Close positions ✅  
- Position tracking ✅
- Symbols list ✅

---

**Last Stable Commit:** Check with `git log v1.1.0-stable`

