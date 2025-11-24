# Fix: Dependency Conflict

## ❌ Error

```
ERROR: Cannot install -r requirements.txt (line 3) and httpx==0.25.0 because these package versions have conflicting dependencies.

The conflict is caused by:
    The user requested httpx==0.25.0
    supabase 2.0.0 depends on httpx<0.25.0 and >=0.24.0
```

## ✅ Solution

`supabase 2.0.0` requires `httpx<0.25.0`, but we had `httpx==0.25.0`.

**Fixed:** Changed to `httpx>=0.24.0,<0.25.0`

## 🔧 Quick Fix on VPS

```bash
# Pull the fix
git pull

# Install with fixed requirements
pip install -r requirements.txt
```

Or install manually:

```bash
pip install "httpx>=0.24.0,<0.25.0"
pip install -r requirements.txt
```

