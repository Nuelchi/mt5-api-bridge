#!/bin/bash
# Test external broker connection with increased timeout
# This script tests HFMarketsGlobal-Demo connection

set -e

echo "🧪 Testing External Broker Connection"
echo "======================================"
echo ""

TOKEN="${1:-your_token_here}"
LOGIN="${2:-49285117}"
PASSWORD="${3:-080662Enc\$}"
SERVER="${4:-HFMarketsGlobal-Demo}"

if [ "$TOKEN" = "your_token_here" ]; then
    echo "❌ Please provide a valid JWT token as first argument"
    echo "Usage: $0 <jwt_token> [login] [password] [server]"
    exit 1
fi

echo "📋 Test Configuration:"
echo "   Login: $LOGIN"
echo "   Server: $SERVER"
echo "   Timeout: 90 seconds (increased for external brokers)"
echo ""

echo "⏳ Attempting connection (this may take up to 90 seconds for external brokers)..."
echo ""

START_TIME=$(date +%s)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://trade.trainflow.dev/api/v1/accounts/connect" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"account_name\": \"$SERVER Test\",
    \"login\": \"$LOGIN\",
    \"password\": \"$PASSWORD\",
    \"server\": \"$SERVER\",
    \"account_type\": \"demo\",
    \"set_as_default\": false
  }" \
  --max-time 95)

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo ""
echo "⏱️  Request took ${DURATION} seconds"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS! Connection established!"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    echo ""
    echo "✅ External broker connection is working!"
elif [ "$HTTP_CODE" = "408" ]; then
    echo "⏱️  TIMEOUT: Connection timed out after ${DURATION} seconds"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Verify server name matches exactly what you see in MT5 terminal"
    echo "   2. Check if broker allows connections from this VPS IP"
    echo "   3. Try connecting manually via VNC first"
    echo "   4. Some brokers may need even more time - check broker documentation"
elif [ "$HTTP_CODE" = "400" ]; then
    echo "❌ BAD REQUEST:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    echo ""
    echo "💡 Check:"
    echo "   1. Login credentials are correct"
    echo "   2. Server name is correct"
    echo "   3. Account is active"
else
    echo "❌ ERROR: HTTP $HTTP_CODE"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
fi

echo ""
echo "📊 Summary:"
echo "   Duration: ${DURATION}s"
echo "   HTTP Code: $HTTP_CODE"
echo "   Server: $SERVER"

