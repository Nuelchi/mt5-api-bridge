#!/usr/bin/env python3
"""
Test MQL5 Compiler Integration
Tests compilation and deployment of AI-generated EAs
"""

import requests
import json
import sys
from pathlib import Path

# Configuration
API_URL = "https://trade.trainflow.dev"
# Get fresh token from: https://dashboard.trainflow.dev
TOKEN = "eyJhbGciOiJIUzI1NiIsImtpZCI6IllTcHdzeW44YVMwdTRNWFMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2tnZnpia3d5ZXBjaGJ5c2F5c2t5LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiIwYjNlMTY1Yy0yNjYxLTQ2NWYtODFiYS1jYjVlOWU0YWJjNjEiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzY0MDkzODk2LCJpYXQiOjE3NjQwOTAyOTYsImVtYWlsIjoiZG94YWZvcmV4NTVAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbCI6ImRveGFmb3JleDU1QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaG9uZV92ZXJpZmllZCI6ZmFsc2UsInN1YiI6IjBiM2UxNjVjLTI2NjEtNDY1Zi04MWJhLWNiNWU5ZTRhYmM2MSJ9LCJyb2xlIjoiYXV0aGVudGljYXRlZCIsImFhbCI6ImFhbDEiLCJhbXIiOlt7Im1ldGhvZCI6InBhc3N3b3JkIiwidGltZXN0YW1wIjoxNzY0MDkwMjk2fV0sInNlc3Npb25faWQiOiIwMjc0ZTE2YS1lYTk1LTRmNzMtOTU5Mi1jMDllZGY2ZjQyNGQiLCJpc19hbm9ueW1vdXMiOmZhbHNlfQ.YWLmEJOx5PqoRPrGKSZQqhk-iwV28oVxlVCx6FKY0M4"

def print_section(title):
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70 + "\n")

def test_compilation():
    """Test 1: Compile Only"""
    print_section("Test 1: Compile MQL5 EA")
    
    # Read sample EA
    ea_file = Path("sample_eas/MA_Crossover_Basic.mq5")
    if not ea_file.exists():
        print("❌ Sample EA file not found")
        return False
    
    with open(ea_file, 'r') as f:
        ea_code = f.read()
    
    # Test compilation
    url = f"{API_URL}/api/v1/algorithms/compile"
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    }
    
    data = {
        "code": ea_code,
        "filename": "MA_Crossover_Test.mq5",
        "validate_only": False
    }
    
    print(f"📡 Compiling EA...")
    print(f"   URL: {url}")
    print(f"   Filename: {data['filename']}")
    print(f"   Code length: {len(ea_code)} characters\n")
    
    try:
        response = requests.post(url, headers=headers, json=data, timeout=120)
        print(f"Status: {response.status_code}")
        
        result = response.json()
        print(f"\nResponse:")
        print(json.dumps(result, indent=2))
        
        if response.status_code == 200 and result.get("success"):
            print("\n✅ Compilation SUCCESSFUL!")
            print(f"   Compile time: {result.get('compile_time', 0)}s")
            print(f"   Errors: {len(result.get('errors', []))}")
            print(f"   Warnings: {len(result.get('warnings', []))}")
            return True
        else:
            print("\n❌ Compilation FAILED")
            if result.get("errors"):
                print("\nErrors:")
                for error in result.get("errors", [])[:5]:
                    print(f"  - {error}")
            return False
            
    except Exception as e:
        print(f"\n❌ Request failed: {e}")
        return False

def test_deploy():
    """Test 2: Compile and Deploy"""
    print_section("Test 2: Compile and Deploy EA")
    
    # Read sample EA
    ea_file = Path("sample_eas/MA_Crossover_Basic.mq5")
    if not ea_file.exists():
        print("❌ Sample EA file not found")
        return False
    
    with open(ea_file, 'r') as f:
        ea_code = f.read()
    
    # Test deployment
    url = f"{API_URL}/api/v1/algorithms/compile-and-deploy"
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    }
    
    data = {
        "code": ea_code,
        "filename": "TrainflowAI_MA_Crossover.mq5",
        "ea_name": "Trainflow AI MA Crossover v1.0"
    }
    
    print(f"📡 Compiling and deploying EA...")
    print(f"   URL: {url}")
    print(f"   Filename: {data['filename']}")
    print(f"   EA Name: {data['ea_name']}\n")
    
    try:
        response = requests.post(url, headers=headers, json=data, timeout=120)
        print(f"Status: {response.status_code}")
        
        result = response.json()
        print(f"\nResponse:")
        print(json.dumps(result, indent=2))
        
        if response.status_code == 200 and result.get("success"):
            print("\n✅ Deployment SUCCESSFUL!")
            print(f"   EA deployed to: {result.get('deployed_path', 'N/A')}")
            print(f"   Compile time: {result.get('compile_time', 0)}s")
            return True
        else:
            print("\n❌ Deployment FAILED")
            print(f"   Stage: {result.get('stage', 'unknown')}")
            if result.get("error"):
                print(f"   Error: {result['error']}")
            return False
            
    except Exception as e:
        print(f"\n❌ Request failed: {e}")
        return False

def main():
    print_section("🚀 MT5 Compiler Integration Tests")
    
    print("⚠️  Make sure:")
    print("  1. API is running on VPS")
    print("  2. Docker MT5 container is running")
    print("  3. Token is valid (get fresh one if needed)")
    print("\nPress Enter to continue...")
    input()
    
    # Run tests
    results = {
        "Compilation Test": test_compilation(),
        "Deploy Test": test_deploy()
    }
    
    # Summary
    print_section("📊 Test Summary")
    
    for test_name, success in results.items():
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    
    print(f"\nResults: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! Compiler integration working!")
    else:
        print("\n⚠️  Some tests failed. Check errors above.")
        print("\n💡 Rollback command:")
        print("   cd /opt/mt5-api-bridge && git reset --hard v1.1.0-stable && systemctl restart mt5-api")

if __name__ == "__main__":
    main()

