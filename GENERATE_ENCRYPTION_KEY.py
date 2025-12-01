#!/usr/bin/env python3
"""
Generate a new MT5 encryption key for use in both MT5 API Bridge and Backend.
"""

from cryptography.fernet import Fernet

if __name__ == "__main__":
    key = Fernet.generate_key()
    key_str = key.decode('utf-8')
    
    print("=" * 60)
    print("MT5 Encryption Key Generated")
    print("=" * 60)
    print()
    print("Add this to your .env file:")
    print()
    print(f"MT5_ENCRYPTION_KEY={key_str}")
    print()
    print("=" * 60)
    print("⚠️  IMPORTANT:")
    print("   1. Add this key to mt5-api-bridge/.env")
    print("   2. Add this key to trainflow-backend/.env (or Render.com env vars)")
    print("   3. Both services MUST use the same key to encrypt/decrypt passwords")
    print("=" * 60)

