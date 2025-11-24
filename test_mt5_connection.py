#!/usr/bin/env python3
"""
Test MT5 Connection with provided credentials
"""

import sys

# Try to import MT5
try:
    import mt5linux as mt5
    MT5_LIBRARY = "mt5linux"
    print("✅ mt5linux library found")
except ImportError:
    try:
        import MetaTrader5 as mt5
        MT5_LIBRARY = "MetaTrader5"
        print("✅ MetaTrader5 library found")
    except ImportError:
        print("❌ No MT5 library found. Install with: pip install mt5linux")
        sys.exit(1)

# MT5 Credentials
SERVER = "MetaQuotes-Demo"
LOGIN = 5042856355
PASSWORD = "V!QzRxQ7"
INVESTOR = "J@LnDnC7"

print("\n🔐 Testing MT5 Connection...")
print("=" * 60)
print(f"Server: {SERVER}")
print(f"Login: {LOGIN}")
print(f"Library: {MT5_LIBRARY}")
print("=" * 60)

# Initialize MT5
if hasattr(mt5, 'initialize'):
    if not mt5.initialize():
        print(f"❌ MT5 initialization failed: {mt5.last_error()}")
        sys.exit(1)
    print("✅ MT5 initialized")
else:
    print("✅ MT5 library loaded (no initialization needed)")

# Login
print(f"\n🔑 Attempting login...")
authorized = mt5.login(LOGIN, password=PASSWORD, server=SERVER)

if not authorized:
    error = mt5.last_error()
    print(f"❌ Login failed!")
    print(f"   Error: {error}")
    sys.exit(1)

print("✅ Login successful!")

# Get account info
account_info = mt5.account_info()
if account_info:
    print(f"\n📊 Account Information:")
    print(f"   Login: {account_info.login}")
    print(f"   Server: {account_info.server}")
    print(f"   Balance: {account_info.balance}")
    print(f"   Equity: {account_info.equity}")
    print(f"   Currency: {account_info.currency}")
    print(f"   Company: {account_info.company}")
    print(f"\n✅ MT5 Connection Test PASSED!")
else:
    print("⚠️  Could not retrieve account info")

# Shutdown
if hasattr(mt5, 'shutdown'):
    mt5.shutdown()

print("\n" + "=" * 60)

