import logging
import os
from functools import lru_cache
from typing import Optional

from supabase import Client, create_client

logger = logging.getLogger(__name__)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")


@lru_cache(maxsize=1)
def get_supabase_client() -> Optional[Client]:
    """
    Lazily initialize and cache the Supabase client so every module
    shares a single connection pool.
    """
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        logger.warning("Supabase credentials missing – skipping client init")
        return None

    try:
        client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        logger.info("✅ Supabase client initialized")
        return client
    except Exception as exc:
        logger.error("⚠️  Supabase client initialization failed: %s", exc)
        return None


def is_supabase_available() -> bool:
    return get_supabase_client() is not None

