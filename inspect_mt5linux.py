#!/usr/bin/env python3
"""
Inspect mt5linux module to understand its API
"""

import mt5linux as mt5

print("🔍 Inspecting mt5linux module...")
print("=" * 60)
print(f"Module: {mt5}")
print(f"Type: {type(mt5)}")
print("")
print("Available attributes:")
print("-" * 60)
for attr in dir(mt5):
    if not attr.startswith('_'):
        try:
            obj = getattr(mt5, attr)
            print(f"  {attr}: {type(obj).__name__}")
        except:
            print(f"  {attr}: (error accessing)")

print("")
print("=" * 60)
print("Checking for common MT5 methods:")
print("-" * 60)
methods_to_check = ['login', 'initialize', 'account_info', 'connect', 'connect_to', 'terminal_info', 'version']
for method in methods_to_check:
    has_method = hasattr(mt5, method)
    print(f"  {method}: {'✅' if has_method else '❌'}")

print("")
print("=" * 60)
print("Module docstring:")
print("-" * 60)
print(mt5.__doc__ if hasattr(mt5, '__doc__') and mt5.__doc__ else "No docstring")

