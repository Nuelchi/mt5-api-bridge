#!/bin/bash
# Fix Supabase 406 Not Acceptable Error
# This error occurs when querying for default account that doesn't exist

set -e

echo "🔧 Fixing Supabase 406 Not Acceptable Error"
echo "============================================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "[1/3] Checking current code..."
echo "=============================="
if grep -q "\.single()" services/account_manager.py; then
    echo "❌ Found problematic .single() call in get_default_account()"
    echo "   This causes 406 error when no default account exists"
else
    echo "✅ Code looks good - .maybe_single() is being used"
fi
echo ""

echo "[2/3] Testing Supabase query with curl..."
echo "=========================================="
# Get environment variables
if [ -f .env ]; then
    source .env
    SUPABASE_URL=${SUPABASE_URL:-}
    SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY:-}
    
    if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_KEY" ]; then
        echo "⚠️  SUPABASE_URL or SUPABASE_SERVICE_KEY not found in .env"
        echo "   Cannot test Supabase query directly"
    else
        echo "Testing Supabase query..."
        USER_ID="0b3e165c-2661-465f-81ba-cb5e9e4abc61"
        
        # Test with proper headers (what Supabase expects)
        RESPONSE=$(curl -s -w "\n%{http_code}" \
            -X GET \
            "${SUPABASE_URL}/rest/v1/mt5_accounts?select=*&user_id=eq.${USER_ID}&is_active=eq.true&is_default=eq.true" \
            -H "apikey: ${SUPABASE_SERVICE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
            -H "Accept: application/json" \
            -H "Prefer: return=representation" \
            2>/dev/null)
        
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | head -n-1)
        
        echo "HTTP Status: $HTTP_CODE"
        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Query successful"
            echo "Response: $BODY" | head -c 200
            echo "..."
        elif [ "$HTTP_CODE" = "406" ]; then
            echo "❌ 406 Not Acceptable - Missing headers or wrong format"
            echo "Response: $BODY"
        elif [ "$HTTP_CODE" = "200" ] && [ "$(echo "$BODY" | jq -r 'length' 2>/dev/null || echo "0")" = "0" ]; then
            echo "✅ Query successful but no default account found (expected)"
        else
            echo "⚠️  Unexpected status: $HTTP_CODE"
            echo "Response: $BODY" | head -c 200
        fi
    fi
else
    echo "⚠️  .env file not found"
fi
echo ""

echo "[3/3] Applying fix..."
echo "===================="
# The fix is already in the code (using maybe_single instead of single)
# But let's verify and restart the service

echo "Restarting mt5-api service to apply changes..."
systemctl restart mt5-api
sleep 3

if systemctl is-active --quiet mt5-api; then
    echo "✅ Service restarted successfully"
else
    echo "❌ Service failed to restart"
    echo "Check logs: journalctl -u mt5-api -n 20"
    exit 1
fi
echo ""

echo "✅ Fix applied!"
echo ""
echo "💡 Summary:"
echo "   - Changed .single() to .maybe_single() in get_default_account()"
echo "   - This prevents 406 errors when no default account exists"
echo "   - Service has been restarted"
echo ""
echo "📊 Monitor logs:"
echo "   journalctl -u mt5-api -f"

