#!/usr/bin/env python3
"""
Test JWT Authentication for MT5 API Bridge
Verifies that Supabase JWT tokens from frontend work correctly
"""

import os
import sys
from pathlib import Path

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

from supabase import create_client

# Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

# Test JWT token (get this from your frontend after login)
TEST_JWT_TOKEN = os.getenv("TEST_JWT_TOKEN", "")

def test_supabase_connection():
    """Test Supabase client connection"""
    print("🔐 Testing Supabase Connection...")
    print(f"📡 Supabase URL: {SUPABASE_URL}")
    print(f"🔑 Anon Key: {SUPABASE_ANON_KEY[:20]}..." if SUPABASE_ANON_KEY else "❌ Not set")
    print()
    
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        print("❌ SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env")
        return False, None
    
    try:
        supabase_client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        print("✅ Supabase client created successfully")
        return True, supabase_client
    except Exception as e:
        print(f"❌ Failed to create Supabase client: {e}")
        return False, None

def test_jwt_verification(supabase_client):
    """Test JWT token verification"""
    print("\n🔍 Testing JWT Token Verification...")
    
    if not TEST_JWT_TOKEN:
        print("⚠️  TEST_JWT_TOKEN not set in .env")
        print("   To test, add TEST_JWT_TOKEN=your_jwt_token to .env")
        print("   You can get this from browser console after logging in:")
        print("   localStorage.getItem('supabase.auth.token')")
        return False, None
    
    print(f"🎫 Token: {TEST_JWT_TOKEN[:50]}...")
    print()
    
    try:
        # Verify token using Supabase client (same as MT5 server)
        response = supabase_client.auth.get_user(TEST_JWT_TOKEN)
        
        if response.user:
            user = response.user
            print("✅ JWT token verified successfully!")
            print(f"🆔 User ID: {user.id}")
            print(f"📧 Email: {user.email}")
            print(f"🔒 Role: {getattr(user, 'role', 'authenticated')}")
            
            user_info = {
                "user_id": user.id,
                "email": user.email,
                "provider": "supabase"
            }
            
            print("\n📋 User info that MT5 server will extract:")
            for key, value in user_info.items():
                print(f"   {key}: {value}")
            
            return True, user_info
        else:
            print("❌ Token verification failed - no user returned")
            return False, None
            
    except Exception as e:
        print(f"❌ JWT verification failed: {e}")
        import traceback
        traceback.print_exc()
        return False, None

def test_api_endpoint():
    """Test API endpoint with JWT token"""
    print("\n🌐 Testing API Endpoint...")
    
    if not TEST_JWT_TOKEN:
        print("⚠️  Skipping API test - no JWT token")
        return False
    
    import httpx
    
    api_url = os.getenv("API_URL", "http://localhost:8001")
    
    try:
        # Test health endpoint (no auth needed)
        print(f"📡 Testing health endpoint: {api_url}/health")
        response = httpx.get(f"{api_url}/health", timeout=5.0)
        
        if response.status_code == 200:
            print("✅ Health endpoint working")
            print(f"   Response: {response.json()}")
        else:
            print(f"⚠️  Health endpoint returned: {response.status_code}")
        
        # Test authenticated endpoint
        print(f"\n📡 Testing authenticated endpoint: {api_url}/api/v1/account/info")
        response = httpx.get(
            f"{api_url}/api/v1/account/info",
            headers={"Authorization": f"Bearer {TEST_JWT_TOKEN}"},
            timeout=5.0
        )
        
        if response.status_code == 200:
            print("✅ Authenticated endpoint working!")
            print(f"   Response: {response.json()}")
            return True
        elif response.status_code == 401:
            print("❌ Authentication failed - check JWT token")
            print(f"   Response: {response.text}")
            return False
        else:
            print(f"⚠️  Unexpected status: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except httpx.ConnectError:
        print(f"⚠️  Could not connect to {api_url}")
        print("   Make sure the MT5 API server is running")
        return False
    except Exception as e:
        print(f"❌ API test failed: {e}")
        return False

def main():
    """Run all tests"""
    print("=" * 60)
    print("🧪 MT5 API Bridge - JWT Authentication Test")
    print("=" * 60)
    print()
    
    # Test 1: Supabase connection
    success, supabase_client = test_supabase_connection()
    if not success:
        print("\n❌ Supabase connection test FAILED")
        print("   Fix SUPABASE_URL and SUPABASE_ANON_KEY in .env")
        return False
    
    # Test 2: JWT verification
    success, user_info = test_jwt_verification(supabase_client)
    if not success:
        print("\n⚠️  JWT verification test SKIPPED or FAILED")
        print("   Add TEST_JWT_TOKEN to .env to test JWT verification")
    else:
        print("\n✅ JWT verification test PASSED")
    
    # Test 3: API endpoint (optional)
    if TEST_JWT_TOKEN:
        api_success = test_api_endpoint()
        if api_success:
            print("\n✅ API endpoint test PASSED")
        else:
            print("\n⚠️  API endpoint test FAILED")
    
    print("\n" + "=" * 60)
    if success:
        print("🎯 Overall: JWT Authentication is WORKING ✅")
        print("   Your MT5 API Bridge can verify tokens from frontend!")
    else:
        print("🎯 Overall: JWT Authentication needs configuration ⚠️")
        print("   Check your .env file and Supabase credentials")
    print("=" * 60)
    
    return success

if __name__ == "__main__":
    try:
        from dotenv import load_dotenv
    except ImportError:
        print("⚠️  python-dotenv not installed. Install with: pip install python-dotenv")
        print("   Or set environment variables manually")
    
    success = main()
    sys.exit(0 if success else 1)

