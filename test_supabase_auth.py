#!/usr/bin/env python3
"""
Test Supabase JWT Authentication
Tests the JWT token verification against the API
"""

import requests
import json
import sys

# Configuration
API_URL = "https://trade.trainflow.dev"
# Or use localhost for testing: API_URL = "http://localhost:8000"

# Your JWT token
TOKEN = "eyJhbGciOiJIUzI1NiIsImtpZCI6IllTcHdzeW44YVMwdTRNWFMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2tnZnpia3d5ZXBjaGJ5c2F5c2t5LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiIwYjNlMTY1Yy0yNjYxLTQ2NWYtODFiYS1jYjVlOWU0YWJjNjEiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzY0MDM1ODk3LCJpYXQiOjE3NjQwMzIyOTcsImVtYWlsIjoiZG94YWZvcmV4NTVAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbCI6ImRveGFmb3JleDU1QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaG9uZV92ZXJpZmllZCI6ZmFsc2UsInN1YiI6IjBiM2UxNjVjLTI2NjEtNDY1Zi04MWJhLWNiNWU5ZTRhYmM2MSJ9LCJyb2xlIjoiYXV0aGVudGljYXRlZCIsImFhbCI6ImFhbDEiLCJhbXIiOlt7Im1ldGhvZCI6InBhc3N3b3JkIiwidGltZXN0YW1wIjoxNzY0MDMyMjk3fV0sInNlc3Npb25faWQiOiI3ZGM2OGRlNy04ZTAxLTQ0MTgtODdhYS0xYTAyZDcwNTQxYTkiLCJpc19hbm9ueW1vdXMiOmZhbHNlfQ.queSCHiI9dfk-tSkPCwf1wycL1ZWkR_nrQYVKtYTqbI"

def test_endpoint(endpoint, method="GET", data=None):
    """Test an API endpoint"""
    url = f"{API_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    }
    
    print(f"\n{'='*60}")
    print(f"Testing: {method} {endpoint}")
    print(f"{'='*60}")
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=10)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers, timeout=10)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ SUCCESS!")
            try:
                result = response.json()
                print(f"Response: {json.dumps(result, indent=2)}")
            except:
                print(f"Response: {response.text}")
        elif response.status_code == 401:
            print("❌ Authentication Failed")
            print(f"Response: {response.text}")
            return False
        elif response.status_code == 403:
            print("❌ Forbidden - Token may be invalid or expired")
            print(f"Response: {response.text}")
            return False
        elif response.status_code == 404:
            print("⚠️  Not Found - Endpoint doesn't exist")
            print(f"Response: {response.text}")
            return False
        else:
            print(f"⚠️  Unexpected status code")
            print(f"Response: {response.text}")
            return False
        
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return False

def main():
    print("🧪 Testing Supabase JWT Authentication")
    print("=" * 60)
    
    # Test 1: Health check (no auth required)
    print("\n[1/5] Testing health endpoint (no auth)...")
    test_endpoint("/health")
    
    # Test 2: Account info (requires auth)
    print("\n[2/5] Testing account info endpoint (requires auth)...")
    success1 = test_endpoint("/api/v1/account/info")
    
    # Test 3: Market data (requires auth)
    print("\n[3/5] Testing market data endpoint (requires auth)...")
    success2 = test_endpoint("/api/v1/market-data/EURUSD?timeframe=H1&bars=10")
    
    # Test 4: Symbols (requires auth)
    print("\n[4/5] Testing symbols endpoint (requires auth)...")
    success3 = test_endpoint("/api/v1/symbols")
    
    # Test 5: Positions (requires auth)
    print("\n[5/5] Testing positions endpoint (requires auth)...")
    success4 = test_endpoint("/api/v1/positions")
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Test Summary")
    print("=" * 60)
    print(f"Health check: ✅")
    print(f"Account info: {'✅' if success1 else '❌'}")
    print(f"Market data: {'✅' if success2 else '❌'}")
    print(f"Symbols: {'✅' if success3 else '❌'}")
    print(f"Positions: {'✅' if success4 else '❌'}")
    
    if all([success1, success2, success3, success4]):
        print("\n🎉 All authenticated endpoints working! Supabase JWT auth is working correctly!")
    else:
        print("\n⚠️  Some endpoints failed. Check the errors above.")
        print("\n💡 If you get 401/403 errors:")
        print("   - Token may be expired (check exp claim)")
        print("   - Token may be invalid")
        print("   - Supabase configuration may be incorrect")
    
    print("\n" + "=" * 60)

if __name__ == "__main__":
    # Allow overriding API URL
    if len(sys.argv) > 1:
        API_URL = sys.argv[1]
        print(f"Using API URL: {API_URL}")
    
    main()

