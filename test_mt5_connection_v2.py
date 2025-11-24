#!/usr/bin/env python3
"""
Test MT5 Connection - Updated for mt5linux compatibility
mt5linux may require MT5 terminal to be running separately
"""

import sys

# Try to import MT5
try:
    import mt5linux as mt5
    MT5_LIBRARY = "mt5linux"
    print("✅ mt5linux library found")
    
    # Inspect available methods
    print("\n🔍 Available methods in mt5linux:")
    methods = [m for m in dir(mt5) if not m.startswith('_')]
    for method in methods[:20]:  # Show first 20
        print(f"   - {method}")
    if len(methods) > 20:
        print(f"   ... and {len(methods) - 20} more")
    
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

# Try different connection methods based on library
if MT5_LIBRARY == "mt5linux":
    print("\n📋 mt5linux detected - checking connection methods...")
    
    # Method 1: Check if initialize exists
    if hasattr(mt5, 'initialize'):
        print("   Trying initialize()...")
        if mt5.initialize():
            print("   ✅ MT5 initialized")
        else:
            print(f"   ❌ Initialize failed: {mt5.last_error() if hasattr(mt5, 'last_error') else 'Unknown error'}")
    
    # Method 2: Check if connect exists
    if hasattr(mt5, 'connect'):
        print("   Trying connect()...")
        try:
            result = mt5.connect(login=LOGIN, password=PASSWORD, server=SERVER)
            print(f"   Connect result: {result}")
        except Exception as e:
            print(f"   Connect error: {e}")
    
    # Method 3: Check if connect_to exists
    if hasattr(mt5, 'connect_to'):
        print("   Trying connect_to()...")
        try:
            result = mt5.connect_to(login=LOGIN, password=PASSWORD, server=SERVER)
            print(f"   Connect_to result: {result}")
        except Exception as e:
            print(f"   Connect_to error: {e}")
    
    # Method 4: Check terminal_info (might work if terminal is already running)
    if hasattr(mt5, 'terminal_info'):
        print("   Checking terminal_info()...")
        try:
            info = mt5.terminal_info()
            if info:
                print(f"   ✅ Terminal info retrieved: {info}")
            else:
                print("   ⚠️  Terminal info returned None")
        except Exception as e:
            print(f"   Terminal info error: {e}")
    
    # Method 5: Check account_info (might work if already connected)
    if hasattr(mt5, 'account_info'):
        print("   Checking account_info()...")
        try:
            account = mt5.account_info()
            if account:
                print(f"   ✅ Account info retrieved!")
                print(f"      Login: {account.login if hasattr(account, 'login') else 'N/A'}")
                print(f"      Server: {account.server if hasattr(account, 'server') else 'N/A'}")
            else:
                print("   ⚠️  Account info returned None (not connected)")
        except Exception as e:
            print(f"   Account info error: {e}")
    
    print("\n💡 Note: mt5linux may require MT5 terminal to be running separately.")
    print("   The library might connect to an already-running MT5 terminal instance.")
    
elif MT5_LIBRARY == "MetaTrader5":
    # Standard Windows MetaTrader5 library approach
    print("\n📋 MetaTrader5 library detected - using standard API...")
    
    # Initialize
    if hasattr(mt5, 'initialize'):
        if not mt5.initialize():
            print(f"❌ MT5 initialization failed: {mt5.last_error()}")
            sys.exit(1)
        print("✅ MT5 initialized")
    
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

