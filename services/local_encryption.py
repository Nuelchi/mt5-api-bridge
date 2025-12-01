"""
Local encryption fallback for MT5 passwords using Fernet (matches backend implementation).
Used when backend encryption service is unavailable.
"""

import logging
import os
from typing import Optional
from cryptography.fernet import Fernet

logger = logging.getLogger(__name__)

# Global cipher instance
_cipher: Optional[Fernet] = None


def _initialize_cipher():
    """Initialize Fernet cipher with encryption key from environment."""
    global _cipher
    
    if _cipher is not None:
        return _cipher
    
    encryption_key = os.getenv('MT5_ENCRYPTION_KEY', '').strip()
    
    if not encryption_key:
        logger.warning("MT5_ENCRYPTION_KEY not set - local encryption fallback unavailable")
        return None
    
    try:
        _cipher = Fernet(encryption_key.encode())
        logger.info("Local encryption cipher initialized (using MT5_ENCRYPTION_KEY)")
        return _cipher
    except Exception as e:
        logger.error(f"Failed to initialize local encryption cipher: {e}")
        return None


def encrypt_password(password: str) -> Optional[str]:
    """
    Encrypt a password using Fernet encryption.
    
    Args:
        password: Plain text password to encrypt
        
    Returns:
        Encrypted password string or None if encryption fails
    """
    if not password:
        return None
    
    cipher = _initialize_cipher()
    if not cipher:
        logger.warning("Local encryption not available (MT5_ENCRYPTION_KEY not configured)")
        return None
    
    try:
        encrypted = cipher.encrypt(password.encode('utf-8')).decode('utf-8')
        logger.debug("Successfully encrypted password using local encryption")
        return encrypted
    except Exception as e:
        logger.error(f"Failed to encrypt password locally: {e}")
        return None


def decrypt_password(encrypted: str) -> Optional[str]:
    """
    Decrypt a password using Fernet encryption.
    
    Args:
        encrypted: Encrypted password string
        
    Returns:
        Decrypted password string or None if decryption fails
    """
    if not encrypted:
        return None
    
    cipher = _initialize_cipher()
    if not cipher:
        logger.warning("Local encryption not available (MT5_ENCRYPTION_KEY not configured)")
        return None
    
    try:
        decrypted = cipher.decrypt(encrypted.encode('utf-8')).decode('utf-8')
        logger.debug("Successfully decrypted password using local encryption")
        return decrypted
    except Exception as e:
        logger.error(f"Failed to decrypt password locally: {e}")
        return None


def is_available() -> bool:
    """Check if local encryption is available."""
    cipher = _initialize_cipher()
    return cipher is not None

