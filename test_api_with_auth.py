#!/usr/bin/env python3
"""
Test MT5 API with JWT Authentication
Tests all endpoints with a real JWT token
"""

import requests
import json
import sys
from datetime import datetime

# Configuration
API_URL = "https://trade.trainflow.dev"
# Or use localhost: API_URL = "http://localhost:8000"

# Fresh JWT token
TOKEN = "eyJhbGciOiJIUzI1NiIsImtpZCI6IllTcHdzeW44YVMwdTRNWFMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2tnZnpia3d5ZXBjaGJ5c2F5c2t5LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiIwYjNlMTY1Yy0yNjYxLTQ2NWYtODFiYS1jYjVlOWU0YWJjNjEiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzY0MDQxMDc4LCJpYXQiOjE3NjQwMzc0NzgsImVtYWlsIjoiZG94YWZvcmV4NTVAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbCI6ImRveGFmb3JleDU1QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaG9uZV92ZXJpZmllZCI6ZmFsc2UsInN1YiI6IjBiM2UxNjVjLTI2NjEtNDY1Zi04MWJhLWNiNWU5ZTRhYmM2MSJ9LCJyb2xlIjoiYXV0aGVudGljYXRlZCIsImFhbCI6ImFhbDEiLCJhbXIiOlt7Im1ldGhvZCI6InBhc3N3b3JkIiwidGltZXN0YW1wIjoxNzY0MDM3NDc4fV0sInNlc3Npb25faWQiOiI3NjE3NDVlNS0yYjYwLTQ0ZjEtYjlkOC1iNjIxOTg3OGRhMGYiLCJpc19hbm9ueW1vdXMiOmZhbHNlfQ.FQHeoPrD4_d7ktOeS8dMNlraTUpWBp0WUGc6uxpxTlw"

def test_endpoint(endpoint, method="GET", data=None, description=""):
    """Test an API endpoint"""
    url = f"{API_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    }
    
    print(f"\n{'='*70}")
    if description:
        print(f"{description}")
    else:
        print(f"Testing: {method} {endpoint}")
    print(f"{'='*70}")
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=30)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=30)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers, timeout=30)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ SUCCESS!")
            try:
                result = response.json()
                # Pretty print with indentation
                print(f"Response:\n{json.dumps(result, indent=2)}")
                return True, result
            except:
                print(f"Response: {response.text[:500]}")
                return True, response.text
        elif response.status_code == 401:
            print("❌ Authentication Failed")
            print(f"Response: {response.text}")
            return False, None
        elif response.status_code == 403:
            print("❌ Forbidden")
            print(f"Response: {response.text}")
            return False, None
        elif response.status_code == 404:
            print("⚠️  Not Found")
            print(f"Response: {response.text}")
            return False, None
        else:
            print(f"⚠️  Unexpected status code")
            print(f"Response: {response.text[:500]}")
            return False, None
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return False, None

def main():
    print("🧪 Testing MT5 API with JWT Authentication")
    print("=" * 70)
    print(f"API URL: {API_URL}")
    print(f"Token: {TOKEN[:50]}...")
    print()
    
    results = {}
    
    # Test 1: Health check (no auth)
    print("\n[1/6] Health Check (No Auth Required)")
    success, data = test_endpoint("/health", description="Health Check Endpoint")
    results['health'] = success
    
    # Test 2: Account info (requires auth)
    print("\n[2/6] Account Information (Requires Auth)")
    success, data = test_endpoint("/api/v1/account/info", description="Get Account Information")
    results['account'] = success
    if success and data:
        print(f"\n📊 Account Summary:")
        if isinstance(data, dict):
            print(f"   Login: {data.get('login', 'N/A')}")
            print(f"   Balance: {data.get('balance', 'N/A')}")
            print(f"   Equity: {data.get('equity', 'N/A')}")
            print(f"   Server: {data.get('server', 'N/A')}")
    
    # Test 3: Market data - EURUSD H1 (requires auth)
    print("\n[3/6] Market Data - EURUSD H1 (Requires Auth)")
    success, data = test_endpoint(
        "/api/v1/market-data/EURUSD?timeframe=H1&bars=10",
        description="Get EURUSD H1 Historical Data (10 bars)"
    )
    results['market_data'] = success
    if success and data and isinstance(data, dict):
        print(f"\n📊 Market Data Summary:")
        print(f"   Symbol: {data.get('symbol', 'N/A')}")
        print(f"   Timeframe: {data.get('timeframe', 'N/A')}")
        print(f"   Count: {data.get('count', 0)} bars")
        if data.get('data'):
            first_bar = data['data'][0]
            last_bar = data['data'][-1]
            print(f"   First bar time: {datetime.fromtimestamp(first_bar.get('time', 0))}")
            print(f"   Last bar close: {last_bar.get('close', 'N/A')}")
    
    # Test 4: Market data - GBPUSD M15 (requires auth)
    print("\n[4/6] Market Data - GBPUSD M15 (Requires Auth)")
    success, data = test_endpoint(
        "/api/v1/market-data/GBPUSD?timeframe=M15&bars=5",
        description="Get GBPUSD M15 Historical Data (5 bars)"
    )
    results['market_data_gbpusd'] = success
    
    # Test 5: Symbols list (requires auth)
    print("\n[5/6] Available Symbols (Requires Auth)")
    success, data = test_endpoint("/api/v1/symbols", description="Get Available Trading Symbols")
    results['symbols'] = success
    if success and data and isinstance(data, dict):
        symbols_list = data.get('symbols', [])
        print(f"\n📊 Symbols Summary:")
        print(f"   Total symbols: {len(symbols_list)}")
        if symbols_list:
            print(f"   First 10 symbols: {', '.join(symbols_list[:10])}")
    
    # Test 6: Positions (requires auth)
    print("\n[6/6] Open Positions (Requires Auth)")
    success, data = test_endpoint("/api/v1/positions", description="Get Open Trading Positions")
    results['positions'] = success
    if success and data and isinstance(data, dict):
        positions = data.get('positions', [])
        print(f"\n📊 Positions Summary:")
        print(f"   Open positions: {len(positions)}")
        if positions:
            for pos in positions[:3]:  # Show first 3
                print(f"   - {pos.get('symbol', 'N/A')}: {pos.get('volume', 0)} lots, Profit: {pos.get('profit', 0)}")
    
    # Summary
    print("\n" + "=" * 70)
    print("📊 Test Summary")
    print("=" * 70)
    print(f"Health check: {'✅' if results.get('health') else '❌'}")
    print(f"Account info: {'✅' if results.get('account') else '❌'}")
    print(f"Market data (EURUSD): {'✅' if results.get('market_data') else '❌'}")
    print(f"Market data (GBPUSD): {'✅' if results.get('market_data_gbpusd') else '❌'}")
    print(f"Symbols list: {'✅' if results.get('symbols') else '❌'}")
    print(f"Positions: {'✅' if results.get('positions') else '❌'}")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    print()
    print(f"Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! API is working correctly!")
    elif passed > 0:
        print(f"\n⚠️  {passed}/{total} tests passed. Some endpoints may need attention.")
    else:
        print("\n❌ All tests failed. Check API logs and configuration.")
    
    print("\n" + "=" * 70)

if __name__ == "__main__":
    # Allow overriding API URL
    if len(sys.argv) > 1:
        API_URL = sys.argv[1]
        print(f"Using API URL: {API_URL}")
    
    main()

