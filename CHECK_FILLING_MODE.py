#!/usr/bin/env python3
"""
Check what filling modes are available for a symbol
"""

import sys
import os
sys.path.insert(0, '/opt/mt5-api-bridge')

from mt5linux import MetaTrader5

# Connect to MT5
mt5 = MetaTrader5(host='localhost', port=8001)
if not mt5.initialize():
    print("Failed to initialize MT5")
    sys.exit(1)

# Get symbol info
symbol = "EURUSD"
symbol_info = mt5.symbol_info(symbol)

if symbol_info is None:
    print(f"Symbol {symbol} not found")
    sys.exit(1)

print(f"Symbol: {symbol}")
print(f"Symbol info attributes: {dir(symbol_info)}")
print()

# Check for filling_mode
if hasattr(symbol_info, 'filling_mode'):
    print(f"filling_mode attribute exists: {symbol_info.filling_mode}")
    print(f"Type: {type(symbol_info.filling_mode)}")
else:
    print("filling_mode attribute does NOT exist")
print()

# Check for trade_execution
if hasattr(symbol_info, 'trade_execution'):
    print(f"trade_execution attribute exists: {symbol_info.trade_execution}")
else:
    print("trade_execution attribute does NOT exist")
print()

# Try to get constants
ORDER_FILLING_FOK = getattr(MetaTrader5, 'ORDER_FILLING_FOK', None)
ORDER_FILLING_IOC = getattr(MetaTrader5, 'ORDER_FILLING_IOC', None)
ORDER_FILLING_RETURN = getattr(MetaTrader5, 'ORDER_FILLING_RETURN', None)

print(f"ORDER_FILLING_FOK: {ORDER_FILLING_FOK}")
print(f"ORDER_FILLING_IOC: {ORDER_FILLING_IOC}")
print(f"ORDER_FILLING_RETURN: {ORDER_FILLING_RETURN}")
print()

# Try a test order with RETURN mode
if ORDER_FILLING_RETURN:
    print("Testing with ORDER_FILLING_RETURN...")
    trade_request = {
        "action": getattr(MetaTrader5, 'TRADE_ACTION_DEAL', None),
        "symbol": symbol,
        "volume": 0.01,
        "type": getattr(MetaTrader5, 'ORDER_TYPE_BUY', None),
        "price": symbol_info.ask,
        "sl": 0,
        "tp": 0,
        "deviation": 10,
        "magic": 123456,
        "comment": "Test Filling Mode",
        "type_time": getattr(MetaTrader5, 'ORDER_TIME_GTC', None),
        "type_filling": ORDER_FILLING_RETURN,
    }
    
    result = mt5.order_send(trade_request)
    print(f"Result: {result}")
    if hasattr(result, 'retcode'):
        print(f"Retcode: {result.retcode}")
        print(f"Comment: {result.comment}")

