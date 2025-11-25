# Enable AutoTrading in MT5 Terminal

## Issue

When placing trades via API, you may get this error:
```
Order failed: AutoTrading disabled by client (code: 10027)
```

This means AutoTrading is disabled in MT5 Terminal.

## Solution

### Option 1: Enable via VNC (GUI Access)

1. Access MT5 Terminal via VNC:
   ```
   http://147.182.206.223:3000
   ```

2. In MT5 Terminal:
   - Click **Tools** → **Options** (or press `Ctrl+O`)
   - Go to **Expert Advisors** tab
   - Check **Allow automated trading**
   - Check **Allow DLL imports** (if needed)
   - Click **OK**

3. Also enable the AutoTrading button:
   - Look for the **AutoTrading** button in the toolbar (usually shows "AutoTrading" text)
   - Click it to enable (button should turn green/active)

### Option 2: Enable via MT5 Configuration File

If you have SSH access to the VPS:

```bash
# MT5 Terminal stores config in Wine prefix
# Path: ~/.wine/drive_c/Program Files/MetaTrader 5/config/common.ini

# Edit the config file
nano ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/config/common.ini

# Add or update these lines:
[Common]
AllowAutoTrading=1
AllowDllImports=1

# Save and restart MT5 Terminal
```

### Option 3: Enable via Docker Container

If using Docker:

```bash
# Access Docker container
docker exec -it mt5 bash

# Edit config file
nano /config/common.ini

# Add:
[Common]
AllowAutoTrading=1
AllowDllImports=1

# Restart container
docker restart mt5
```

## Verify AutoTrading is Enabled

After enabling, test with:

```bash
# Test trade endpoint
curl -X POST https://trade.trainflow.dev/api/v1/trades \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "order_type": "buy",
    "volume": 0.01
  }'
```

If successful, you should get a response with a ticket number.

## Alternative: Enable Programmatically

You can also enable AutoTrading programmatically via the API (if MT5 Terminal supports it):

```python
# This would need to be added to the API
# Currently, AutoTrading must be enabled manually in MT5 Terminal
```

## Notes

- AutoTrading must be enabled in **each MT5 Terminal instance**
- If you restart MT5 Terminal, AutoTrading may need to be re-enabled
- Some brokers require AutoTrading to be enabled in their client area as well
- Demo accounts usually allow AutoTrading by default, but it may be disabled

## Troubleshooting

If AutoTrading is enabled but trades still fail:

1. **Check MT5 Terminal logs:**
   ```bash
   docker logs mt5 --tail 50
   ```

2. **Verify account permissions:**
   - Some accounts (especially investor accounts) cannot place trades
   - Check if account is a trading account, not investor account

3. **Check broker settings:**
   - Some brokers disable API trading
   - Contact broker to enable API access

4. **Verify symbol is tradeable:**
   ```bash
   curl https://trade.trainflow.dev/api/v1/symbols \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

