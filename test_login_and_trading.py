#!/usr/bin/env python3
"""
Comprehensive test for MT5 login and trading functionality
Tests all endpoints with real credentials
"""

import requests
import json
import sys
from datetime import datetime

# Configuration
API_URL = "https://trade.trainflow.dev"
TOKEN = "eyJhbGciOiJIUzI1NiIsImtpZCI6IllTcHdzeW44YVMwdTRNWFMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2tnZnpia3d5ZXBjaGJ5c2F5c2t5LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiIwYjNlMTY1Yy0yNjYxLTQ2NWYtODFiYS1jYjVlOWU0YWJjNjEiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzY0MDQ1OTY2LCJpYXQiOjE3NjQwNDIzNjYsImVtYWlsIjoiZG94YWZvcmV4NTVAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbCI6ImRveGFmb3JleDU1QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaG9uZV92ZXJpZmllZCI6ZmFsc2UsInN1YiI6IjBiM2UxNjVjLTI2NjEtNDY1Zi04MWJhLWNiNWU5ZTRhYmM2MSJ9LCJyb2xlIjoiYXV0aGVudGljYXRlZCIsImFhbCI6ImFhbDEiLCJhbXIiOlt7Im1ldGhvZCI6InBhc3N3b3JkIiwidGltZXN0YW1wIjoxNzY0MDQyMzY2fV0sInNlc3Npb25faWQiOiI3ODg1YTgwZS1kNmQ1LTQ0ZTEtYWViYi01MjZkNGQ3MWM2NjkiLCJpc19hbm9ueW1vdXMiOmZhbHNlfQ.W1HQPY6cpHRTq3oxA17qsgh67Y5bCvMG57S9tEQuTak"

# MT5 Credentials
MT5_CREDENTIALS = {
    "account_name": "Test Demo Account",
    "login": 5042856355,
    "password": "V!QzRxQ7",
    "server": "MetaQuotes-Demo",
    "broker_name": "MetaQuotes Ltd.",
    "account_type": "demo"
}

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)

def test_endpoint(method, endpoint, data=None, description=""):
    """Test an API endpoint"""
    url = f"{API_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    }
    
    print(f"\n📡 {description or f'{method} {endpoint}'}")
    print(f"   URL: {endpoint}")
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=30)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=30)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers, timeout=30)
        
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=6)}")
            return True, result
        elif response.status_code == 201:
            print("   ✅ CREATED")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=6)}")
            return True, result
        else:
            print(f"   ❌ FAILED")
            try:
                error = response.json()
                print(f"   Error: {json.dumps(error, indent=6)}")
            except:
                print(f"   Error: {response.text[:200]}")
            return False, None
        
    except requests.exceptions.RequestException as e:
        print(f"   ❌ REQUEST ERROR: {e}")
        return False, None

def main():
    print("\n" + "=" * 70)
    print("  🧪 MT5 Login and Trading Test Suite")
    print("=" * 70)
    print(f"\nAPI URL: {API_URL}")
    print(f"MT5 Account: {MT5_CREDENTIALS['login']}")
    print(f"Server: {MT5_CREDENTIALS['server']}")
    
    results = {}
    
    # Test 1: Health Check
    print_section("1. Health Check (No Auth)")
    success, data = test_endpoint("GET", "/health", description="Check API health")
    results['health'] = success
    
    # Test 2: Connect/Login to MT5 Account
    print_section("2. Connect MT5 Account (Login)")
    connect_data = {
        "account_name": MT5_CREDENTIALS["account_name"],
        "login": MT5_CREDENTIALS["login"],
        "password": MT5_CREDENTIALS["password"],
        "server": MT5_CREDENTIALS["server"],
        "broker_name": MT5_CREDENTIALS["broker_name"],
        "account_type": MT5_CREDENTIALS["account_type"]
    }
    success, account_data = test_endpoint(
        "POST", 
        "/api/v1/accounts/connect",
        data=connect_data,
        description="Connect/Login to MT5 Account"
    )
    results['connect'] = success
    
    if success and account_data:
        print(f"\n   📊 Account Connected:")
        if 'account' in account_data:
            acc = account_data['account']
            print(f"      Login: {acc.get('login', 'N/A')}")
            print(f"      Server: {acc.get('server', 'N/A')}")
            print(f"      Balance: {acc.get('balance', 'N/A')}")
            print(f"      Equity: {acc.get('equity', 'N/A')}")
    
    # Test 3: Get Account Info
    print_section("3. Get Account Information")
    success, account_info = test_endpoint(
        "GET",
        "/api/v1/account/info",
        description="Get current account information"
    )
    results['account_info'] = success
    
    if success and account_info:
        print(f"\n   📊 Account Details:")
        print(f"      Login: {account_info.get('login', 'N/A')}")
        print(f"      Balance: ${account_info.get('balance', 'N/A'):,.2f}")
        print(f"      Equity: ${account_info.get('equity', 'N/A'):,.2f}")
        print(f"      Free Margin: ${account_info.get('free_margin', 'N/A'):,.2f}")
        print(f"      Leverage: 1:{account_info.get('leverage', 'N/A')}")
        print(f"      Server: {account_info.get('server', 'N/A')}")
    
    # Test 4: Get Current Positions
    print_section("4. Get Open Positions")
    success, positions_data = test_endpoint(
        "GET",
        "/api/v1/positions",
        description="Get all open positions"
    )
    results['positions'] = success
    
    if success and positions_data:
        positions = positions_data.get('positions', [])
        print(f"\n   📊 Open Positions: {len(positions)}")
        if positions:
            for pos in positions[:5]:  # Show first 5
                print(f"      - {pos.get('symbol', 'N/A')}: {pos.get('type', 'N/A').upper()} "
                      f"{pos.get('volume', 0)} lots @ {pos.get('price_open', 0)} "
                      f"(P/L: ${pos.get('profit', 0):,.2f})")
        else:
            print("      No open positions")
    
    # Test 5: Get Market Data (to check current price)
    print_section("5. Get Market Data (EURUSD)")
    success, market_data = test_endpoint(
        "GET",
        "/api/v1/market-data/EURUSD?timeframe=H1&bars=1",
        description="Get EURUSD current price"
    )
    results['market_data'] = success
    
    if success and market_data:
        data = market_data.get('data', [])
        if data:
            latest = data[0]
            print(f"\n   📊 EURUSD Current Price:")
            print(f"      Open: {latest.get('open', 'N/A')}")
            print(f"      High: {latest.get('high', 'N/A')}")
            print(f"      Low: {latest.get('low', 'N/A')}")
            print(f"      Close: {latest.get('close', 'N/A')}")
            current_price = latest.get('close', 0)
        else:
            current_price = 0
    else:
        current_price = 0
    
    # Test 6: Place a Buy Order
    print_section("6. Place Buy Order (Test Trade)")
    if current_price > 0:
        # Place a small buy order with stop loss and take profit
        buy_order = {
            "symbol": "EURUSD",
            "order_type": "buy",
            "volume": 0.01,  # Minimum volume
            "stop_loss": round(current_price - 0.0010, 5),  # 10 pips SL
            "take_profit": round(current_price + 0.0010, 5)  # 10 pips TP
        }
        success, trade_result = test_endpoint(
            "POST",
            "/api/v1/trades",
            data=buy_order,
            description="Place BUY order for EURUSD"
        )
        results['place_buy'] = success
        
        if success and trade_result:
            print(f"\n   📊 Trade Executed:")
            print(f"      Ticket: {trade_result.get('ticket', 'N/A')}")
            print(f"      Symbol: {trade_result.get('symbol', 'N/A')}")
            print(f"      Type: {trade_result.get('type', 'N/A').upper()}")
            print(f"      Volume: {trade_result.get('volume', 'N/A')} lots")
            print(f"      Price: {trade_result.get('price', 'N/A')}")
            buy_ticket = trade_result.get('ticket')
        else:
            buy_ticket = None
    else:
        print("   ⚠️  Skipping trade - couldn't get market price")
        results['place_buy'] = False
        buy_ticket = None
    
    # Test 7: Place a Sell Order (if buy worked)
    if buy_ticket:
        print_section("7. Place Sell Order (Test Trade)")
        sell_order = {
            "symbol": "EURUSD",
            "order_type": "sell",
            "volume": 0.01,
            "stop_loss": round(current_price + 0.0010, 5),
            "take_profit": round(current_price - 0.0010, 5)
        }
        success, trade_result = test_endpoint(
            "POST",
            "/api/v1/trades",
            data=sell_order,
            description="Place SELL order for EURUSD"
        )
        results['place_sell'] = success
        
        if success and trade_result:
            print(f"\n   📊 Trade Executed:")
            print(f"      Ticket: {trade_result.get('ticket', 'N/A')}")
            print(f"      Symbol: {trade_result.get('symbol', 'N/A')}")
            print(f"      Type: {trade_result.get('type', 'N/A').upper()}")
            print(f"      Volume: {trade_result.get('volume', 'N/A')} lots")
            print(f"      Price: {trade_result.get('price', 'N/A')}")
            sell_ticket = trade_result.get('ticket')
        else:
            sell_ticket = None
    else:
        print("   ⚠️  Skipping sell order - buy order failed")
        results['place_sell'] = False
        sell_ticket = None
    
    # Test 8: Get Positions Again (to see new trades)
    print_section("8. Get Open Positions (After Trades)")
    success, positions_data = test_endpoint(
        "GET",
        "/api/v1/positions",
        description="Get all open positions after trades"
    )
    results['positions_after'] = success
    
    if success and positions_data:
        positions = positions_data.get('positions', [])
        print(f"\n   📊 Open Positions: {len(positions)}")
        if positions:
            for pos in positions:
                print(f"      - Ticket {pos.get('ticket', 'N/A')}: "
                      f"{pos.get('symbol', 'N/A')} {pos.get('type', 'N/A').upper()} "
                      f"{pos.get('volume', 0)} lots @ {pos.get('price_open', 0)} "
                      f"(P/L: ${pos.get('profit', 0):,.2f})")
    
    # Test 9: Close a Position (if we have one)
    if buy_ticket:
        print_section("9. Close Position")
        success, close_result = test_endpoint(
            "DELETE",
            f"/api/v1/positions/{buy_ticket}",
            description=f"Close position {buy_ticket}"
        )
        results['close_position'] = success
        
        if success and close_result:
            print(f"\n   📊 Position Closed:")
            print(f"      Ticket: {close_result.get('closed_ticket', 'N/A')}")
            print(f"      Volume: {close_result.get('volume', 'N/A')} lots")
            print(f"      Price: {close_result.get('price', 'N/A')}")
    else:
        print("   ⚠️  Skipping close - no position to close")
        results['close_position'] = False
    
    # Test 10: Get Account Info Again (to see updated balance)
    print_section("10. Get Account Info (After Trading)")
    success, account_info = test_endpoint(
        "GET",
        "/api/v1/account/info",
        description="Get account information after trading"
    )
    results['account_info_after'] = success
    
    if success and account_info:
        print(f"\n   📊 Updated Account:")
        print(f"      Balance: ${account_info.get('balance', 'N/A'):,.2f}")
        print(f"      Equity: ${account_info.get('equity', 'N/A'):,.2f}")
        print(f"      Profit: ${account_info.get('profit', 'N/A'):,.2f}")
        print(f"      Free Margin: ${account_info.get('free_margin', 'N/A'):,.2f}")
    
    # Summary
    print("\n" + "=" * 70)
    print("  📊 Test Summary")
    print("=" * 70)
    
    test_names = {
        'health': 'Health Check',
        'connect': 'Connect/Login Account',
        'account_info': 'Get Account Info',
        'positions': 'Get Positions',
        'market_data': 'Get Market Data',
        'place_buy': 'Place Buy Order',
        'place_sell': 'Place Sell Order',
        'positions_after': 'Get Positions (After)',
        'close_position': 'Close Position',
        'account_info_after': 'Account Info (After)'
    }
    
    passed = 0
    total = 0
    
    for key, name in test_names.items():
        if key in results:
            status = "✅ PASS" if results[key] else "❌ FAIL"
            print(f"  {status} - {name}")
            if results[key]:
                passed += 1
            total += 1
    
    print(f"\n  Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n  🎉 All tests passed! API is fully functional!")
    elif passed > total * 0.7:
        print(f"\n  ⚠️  Most tests passed ({passed}/{total}). Some features may need attention.")
    else:
        print(f"\n  ❌ Many tests failed ({passed}/{total}). Check API configuration.")
    
    print("\n" + "=" * 70)

if __name__ == "__main__":
    # Allow overriding API URL
    if len(sys.argv) > 1:
        API_URL = sys.argv[1]
        print(f"Using API URL: {API_URL}")
    
    main()

