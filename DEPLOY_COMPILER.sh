#!/bin/bash
#
# Deploy MQL Compiler Integration to VPS
# Quick deployment with rollback capability
#

set -e

echo "🚀 Deploying MQL Compiler Integration"
echo "========================================"
echo ""

# Pull latest code
echo "[1/5] Pulling latest code from GitHub..."
git pull
echo "✅ Code updated"
echo ""

# Check Docker is running
echo "[2/5] Checking Docker MT5 container..."
if docker ps | grep -q "mt5"; then
    echo "✅ Docker MT5 container is running"
else
    echo "❌ Docker MT5 container not running!"
    echo "   Start it with: docker start mt5"
    exit 1
fi
echo ""

# Create temp directory in Docker for compilation
echo "[3/5] Setting up compilation environment..."
docker exec mt5 mkdir -p /tmp/mql_compile || true
docker exec mt5 chmod 777 /tmp/mql_compile || true
echo "✅ Compilation directory ready"
echo ""

# Restart API service
echo "[4/5] Restarting API service..."
systemctl restart mt5-api
sleep 5
echo "✅ API restarted"
echo ""

# Test API health
echo "[5/5] Testing API health..."
response=$(curl -s http://localhost:8000/health)
if echo "$response" | grep -q "healthy"; then
    echo "✅ API is healthy"
    echo ""
    echo "$response" | python3 -m json.tool
else
    echo "❌ API health check failed!"
    echo "$response"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "🧪 Next steps:"
echo "   1. Test locally: python3 test_compiler.py"
echo "   2. Or test via curl (see commands below)"
echo ""
echo "📝 Test compile endpoint:"
echo '   curl -X POST https://trade.trainflow.dev/api/v1/algorithms/compile \'
echo '     -H "Authorization: Bearer YOUR_TOKEN" \'
echo '     -H "Content-Type: application/json" \'
echo '     -d '"'"'{"code": "...", "filename": "test.mq5", "validate_only": false}'"'"
echo ""
echo "🔄 Rollback if needed:"
echo "   git reset --hard v1.1.0-stable && systemctl restart mt5-api"
echo ""

