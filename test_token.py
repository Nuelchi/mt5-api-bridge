#!/usr/bin/env python3
"""
Quick test of the provided JWT token
"""

import os
from supabase import create_client

# Your Supabase credentials
SUPABASE_URL = "https://kgfzbkwyepchbysaysky.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M"

# Your test token
TEST_TOKEN = "eyJhbGciOiJIUzI1NiIsImtpZCI6IllTcHdzeW44YVMwdTRNWFMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2tnZnpia3d5ZXBjaGJ5c2F5c2t5LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiIwYjNlMTY1Yy0yNjYxLTQ2NWYtODFiYS1jYjVlOWU0YWJjNjEiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzY0MDA5NzM3LCJpYXQiOjE3NjQwMDYxMzcsImVtYWlsIjoiZG94YWZvcmV4NTVAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbCI6ImRveGFmb3JleDU1QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaG9uZV92ZXJpZmllZCI6ZmFsc2UsInN1YiI6IjBiM2UxNjVjLTI2NjEtNDY1Zi04MWJhLWNiNWU5ZTRhYmM2MSJ9LCJyb2xlIjoiYXV0aGVudGljYXRlZCIsImFhbCI6ImFhbDEiLCJhbXIiOlt7Im1ldGhvZCI6InBhc3N3b3JkIiwidGltZXN0YW1wIjoxNzY0MDA2MTM3fV0sInNlc3Npb25faWQiOiJlMDIxNWE2NC1lNGVkLTQyZGEtODllOS04NTQ4YTAzMDc3OTkiLCJpc19hbm9ueW1vdXMiOmZhbHNlfQ.XkrOUa3ovvOsqk0v6sfyDhLB4yvpZBVGc1F_MhUNKEU"

print("🧪 Testing JWT Token...")
print("=" * 60)

try:
    # Create Supabase client
    supabase_client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
    print("✅ Supabase client created")
    
    # Verify token
    print("\n🔍 Verifying JWT token...")
    response = supabase_client.auth.get_user(TEST_TOKEN)
    
    if response.user:
        user = response.user
        print("✅ JWT TOKEN VERIFIED SUCCESSFULLY!")
        print(f"\n📋 User Information:")
        print(f"   🆔 User ID: {user.id}")
        print(f"   📧 Email: {user.email}")
        print(f"   🔒 Role: {getattr(user, 'role', 'authenticated')}")
        print(f"   ✅ Email Verified: {getattr(user, 'email_confirmed_at', None) is not None}")
        
        print(f"\n✅ This token will work with MT5 API Bridge!")
        print(f"   The API will extract: user_id={user.id}, email={user.email}")
    else:
        print("❌ Token verification failed - no user returned")
        
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 60)

