#!/usr/bin/env python3
"""
Test MT5 Connection - Using mt5linux.MetaTrader5 class
"""

import sys

# Import mt5linux
try:
    from mt5linux import MetaTrader5
    print("✅ mt5linux library found")
except ImportError:
    print("❌ mt5linux not found")
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
print("=" * 60)

# Inspect MetaTrader5 class
print("\n🔍 Inspecting MetaTrader5 class...")
print("-" * 60)
methods = [m for m in dir(MetaTrader5) if not m.startswith('_')]
print(f"Available methods ({len(methods)}):")
for method in methods[:30]:  # Show first 30
    print(f"   - {method}")
if len(methods) > 30:
    print(f"   ... and {len(methods) - 30} more")

# Try to instantiate
print("\n📋 Attempting to create MetaTrader5 instance...")
print("-" * 60)

# Method 1: Create instance without parameters
try:
    mt5 = MetaTrader5()
    print("✅ MetaTrader5() instance created")
    
    # Check available methods on instance
    instance_methods = [m for m in dir(mt5) if not m.startswith('_')]
    print(f"\n📋 Instance methods ({len(instance_methods)}):")
    for method in instance_methods[:20]:
        print(f"   - {method}")
    
    # Try common methods
    print("\n🧪 Testing common methods...")
    
    # Try initialize
    if hasattr(mt5, 'initialize'):
        print("   Trying initialize()...")
        try:
            result = mt5.initialize()
            print(f"   ✅ initialize() result: {result}")
        except Exception as e:
            print(f"   ❌ initialize() error: {e}")
    
    # Try login
    if hasattr(mt5, 'login'):
        print("   Trying login()...")
        try:
            result = mt5.login(LOGIN, password=PASSWORD, server=SERVER)
            print(f"   ✅ login() result: {result}")
            if result:
                # Try account_info
                if hasattr(mt5, 'account_info'):
                    account = mt5.account_info()
                    if account:
                        print(f"\n📊 Account Information:")
                        print(f"   Login: {account.login if hasattr(account, 'login') else 'N/A'}")
                        print(f"   Server: {account.server if hasattr(account, 'server') else 'N/A'}")
                        print(f"   Balance: {account.balance if hasattr(account, 'balance') else 'N/A'}")
        except Exception as e:
            print(f"   ❌ login() error: {e}")
    
    # Try connect
    if hasattr(mt5, 'connect'):
        print("   Trying connect()...")
        try:
            result = mt5.connect(login=LOGIN, password=PASSWORD, server=SERVER)
            print(f"   ✅ connect() result: {result}")
        except Exception as e:
            print(f"   ❌ connect() error: {e}")
    
    # Try account_info (might work if already connected)
    if hasattr(mt5, 'account_info'):
        print("   Trying account_info()...")
        try:
            account = mt5.account_info()
            if account:
                print(f"   ✅ account_info() retrieved:")
                print(f"      Type: {type(account)}")
                print(f"      Attributes: {[a for a in dir(account) if not a.startswith('_')][:10]}")
            else:
                print("   ⚠️  account_info() returned None")
        except Exception as e:
            print(f"   ❌ account_info() error: {e}")
    
except Exception as e:
    print(f"❌ Failed to create instance: {e}")
    import traceback
    traceback.print_exc()

# Method 2: Try creating with parameters
print("\n📋 Attempting to create MetaTrader5 instance with parameters...")
print("-" * 60)
try:
    mt5 = MetaTrader5(login=LOGIN, password=PASSWORD, server=SERVER)
    print("✅ MetaTrader5(login, password, server) instance created")
    
    # Check if it's connected
    if hasattr(mt5, 'account_info'):
        account = mt5.account_info()
        if account:
            print(f"\n📊 Account Information:")
            print(f"   Login: {account.login if hasattr(account, 'login') else 'N/A'}")
            print(f"   Server: {account.server if hasattr(account, 'server') else 'N/A'}")
            print(f"   Balance: {account.balance if hasattr(account, 'balance') else 'N/A'}")
            print(f"\n✅ Connection successful!")
        else:
            print("⚠️  Instance created but account_info() returned None")
except Exception as e:
    print(f"❌ Failed to create instance with parameters: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 60)

