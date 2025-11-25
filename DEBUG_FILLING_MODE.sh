#!/bin/bash
# Debug filling mode issue - check constants and test directly

set -e

echo "🔍 Debugging Filling Mode Issue"
echo "================================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "[1/3] Checking MT5 constants..."
python3 <<PYEOF
from mt5linux import MetaTrader5

mt5 = MetaTrader5(host='localhost', port=8001)
if not mt5.initialize():
    print("Failed to initialize")
    exit(1)

# Check constants
print("Checking ORDER_FILLING constants:")
ORDER_FILLING_FOK = getattr(MetaTrader5, 'ORDER_FILLING_FOK', None)
ORDER_FILLING_IOC = getattr(MetaTrader5, 'ORDER_FILLING_IOC', None)
ORDER_FILLING_RETURN = getattr(MetaTrader5, 'ORDER_FILLING_RETURN', None)

print(f"  ORDER_FILLING_FOK: {ORDER_FILLING_FOK}")
print(f"  ORDER_FILLING_IOC: {ORDER_FILLING_IOC}")
print(f"  ORDER_FILLING_RETURN: {ORDER_FILLING_RETURN}")
print()

# Check symbol info
symbol = "EURUSD"
symbol_info = mt5.symbol_info(symbol)
if symbol_info:
    print(f"Symbol {symbol} info:")
    print(f"  Has filling_mode attribute: {hasattr(symbol_info, 'filling_mode')}")
    if hasattr(symbol_info, 'filling_mode'):
        print(f"  filling_mode value: {symbol_info.filling_mode}")
        print(f"  filling_mode type: {type(symbol_info.filling_mode)}")
    print(f"  All attributes: {[a for a in dir(symbol_info) if not a.startswith('_')]}")
PYEOF

echo ""
echo "[2/3] Checking API logs for filling mode errors..."
journalctl -u mt5-api -n 50 --no-pager | grep -i "filling\|order\|trade" | tail -20 || echo "No relevant logs found"
echo ""

echo "[3/3] Testing order with different filling modes..."
python3 <<PYEOF
from mt5linux import MetaTrader5

mt5 = MetaTrader5(host='localhost', port=8001)
if not mt5.initialize():
    print("Failed to initialize")
    exit(1)

symbol = "EURUSD"
symbol_info = mt5.symbol_info(symbol)
if not symbol_info:
    print(f"Symbol {symbol} not found")
    exit(1)

# Get constants
ORDER_FILLING_FOK = getattr(MetaTrader5, 'ORDER_FILLING_FOK', None)
ORDER_FILLING_IOC = getattr(MetaTrader5, 'ORDER_FILLING_IOC', None)
ORDER_FILLING_RETURN = getattr(MetaTrader5, 'ORDER_FILLING_RETURN', None)
TRADE_ACTION_DEAL = getattr(MetaTrader5, 'TRADE_ACTION_DEAL', None)
ORDER_TYPE_BUY = getattr(MetaTrader5, 'ORDER_TYPE_BUY', None)
ORDER_TIME_GTC = getattr(MetaTrader5, 'ORDER_TIME_GTC', None)

print(f"Constants:")
print(f"  TRADE_ACTION_DEAL: {TRADE_ACTION_DEAL}")
print(f"  ORDER_TYPE_BUY: {ORDER_TYPE_BUY}")
print(f"  ORDER_TIME_GTC: {ORDER_TIME_GTC}")
print()

# Try without type_filling first
print("Testing order WITHOUT type_filling...")
trade_request = {
    "action": TRADE_ACTION_DEAL,
    "symbol": symbol,
    "volume": 0.01,
    "type": ORDER_TYPE_BUY,
    "price": symbol_info.ask,
    "sl": 0,
    "tp": 0,
    "deviation": 10,
    "magic": 123456,
    "comment": "Test No Filling Mode",
    "type_time": ORDER_TIME_GTC,
}

result = mt5.order_send(trade_request)
print(f"  Result: retcode={result.retcode}, comment={result.comment}")
if result.retcode == 10009:  # TRADE_RETCODE_DONE
    print("  ✅ SUCCESS! Order worked without type_filling")
    exit(0)
print()

# Try with RETURN
if ORDER_FILLING_RETURN:
    print(f"Testing order WITH ORDER_FILLING_RETURN ({ORDER_FILLING_RETURN})...")
    trade_request["type_filling"] = ORDER_FILLING_RETURN
    trade_request["comment"] = "Test RETURN"
    result = mt5.order_send(trade_request)
    print(f"  Result: retcode={result.retcode}, comment={result.comment}")
    if result.retcode == 10009:
        print("  ✅ SUCCESS! Order worked with RETURN")
        exit(0)
print()

print("❌ All filling modes failed")
PYEOF

echo ""

