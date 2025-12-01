#!/bin/bash
# Complete VPS Cleanup Script
# Run this BEFORE deploying to ensure a clean slate
# Usage: bash CLEANUP_VPS.sh

set -e

echo "🧹 MT5 API Bridge - VPS Cleanup Script"
echo "======================================="
echo ""
echo "⚠️  WARNING: This will remove all MT5 API Bridge installations!"
echo "⚠️  This includes services, directories, and configurations."
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled."
    exit 1
fi

echo ""
echo "🚀 Starting cleanup process..."
echo ""

# Step 1: Stop all services
echo "[1/7] Stopping all services..."
echo "-------------------------------"
systemctl stop mt5-api 2>/dev/null && echo "   ✅ Stopped mt5-api" || echo "   ⚠️  mt5-api not running"
systemctl stop nginx 2>/dev/null && echo "   ✅ Stopped nginx" || echo "   ⚠️  nginx not running"
docker stop mt5 2>/dev/null && echo "   ✅ Stopped docker mt5" || echo "   ⚠️  docker mt5 not running"
docker rm mt5 2>/dev/null && echo "   ✅ Removed docker mt5 container" || echo "   ⚠️  docker mt5 container not found"

# Step 2: Disable and remove services
echo ""
echo "[2/7] Removing systemd services..."
echo "----------------------------------"
systemctl disable mt5-api 2>/dev/null || true
rm -f /etc/systemd/system/mt5-api.service && echo "   ✅ Removed mt5-api.service" || echo "   ⚠️  Service file not found"
systemctl daemon-reload && echo "   ✅ Reloaded systemd daemon"

# Step 3: Remove old directories
echo ""
echo "[3/7] Removing old directories..."
echo "---------------------------------"
DIRS_TO_REMOVE=(
    "/opt/mt5-api-bridge"
    "/opt/MetaTrader5-Docker"
    "/opt/mt5"
    "/home/mt5"
    "/var/www/mt5"
)

for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir" && echo "   ✅ Removed $dir" || echo "   ❌ Failed to remove $dir"
    else
        echo "   ⚠️  $dir does not exist (skipping)"
    fi
done

# Step 4: Clean up Python environments and cache
echo ""
echo "[4/7] Cleaning Python environments and cache..."
echo "-----------------------------------------------"
rm -rf ~/.cache/pip && echo "   ✅ Removed pip cache" || echo "   ⚠️  Pip cache not found"
find /opt -type d -name "venv" -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed virtual environments" || echo "   ⚠️  No virtual environments found"

# Step 5: Remove old log files
echo ""
echo "[5/7] Cleaning log files..."
echo "--------------------------"
rm -rf /var/log/mt5-api 2>/dev/null && echo "   ✅ Removed mt5-api logs" || echo "   ⚠️  Log directory not found"
journalctl --vacuum-time=1d 2>/dev/null && echo "   ✅ Cleaned systemd logs" || echo "   ⚠️  Could not clean systemd logs"

# Step 6: Remove Nginx configuration (optional)
echo ""
echo "[6/7] Checking Nginx configuration..."
echo "-------------------------------------"
if [ -f "/etc/nginx/sites-enabled/mt5-api" ]; then
    read -p "   Remove Nginx configuration? (y/n): " remove_nginx
    if [[ $remove_nginx =~ ^[Yy]$ ]]; then
        rm -f /etc/nginx/sites-enabled/mt5-api
        rm -f /etc/nginx/sites-available/mt5-api
        nginx -t && systemctl reload nginx && echo "   ✅ Removed Nginx configuration" || echo "   ⚠️  Nginx config removed but reload failed"
    else
        echo "   ⚠️  Keeping Nginx configuration"
    fi
else
    echo "   ⚠️  Nginx configuration not found"
fi

# Step 7: Verify cleanup
echo ""
echo "[7/7] Verifying cleanup..."
echo "--------------------------"
echo ""
echo "Checking for remaining MT5 directories:"
REMAINING_DIRS=$(find /opt -maxdepth 1 -type d -name "*mt5*" -o -name "*MetaTrader*" 2>/dev/null)
if [ -z "$REMAINING_DIRS" ]; then
    echo "   ✅ No MT5 directories found"
else
    echo "   ⚠️  Remaining directories:"
    echo "$REMAINING_DIRS"
fi

echo ""
echo "Checking for MT5 services:"
REMAINING_SERVICES=$(systemctl list-units --all | grep -i mt5 || true)
if [ -z "$REMAINING_SERVICES" ]; then
    echo "   ✅ No MT5 services found"
else
    echo "   ⚠️  Remaining services:"
    echo "$REMAINING_SERVICES"
fi

echo ""
echo "Checking for processes on port 8001:"
PORT_CHECK=$(lsof -i :8001 2>/dev/null || netstat -tlnp 2>/dev/null | grep 8001 || true)
if [ -z "$PORT_CHECK" ]; then
    echo "   ✅ Port 8001 is free"
else
    echo "   ⚠️  Port 8001 is in use:"
    echo "$PORT_CHECK"
fi

echo ""
echo "=========================================="
echo "✅ Cleanup Complete!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "   ✅ Services stopped"
echo "   ✅ Directories removed"
echo "   ✅ Python environments cleaned"
echo "   ✅ Logs cleaned"
echo ""
echo "📋 Next Steps:"
echo "   1. Run the deployment script: bash VPS_DEPLOYMENT.sh"
echo "   2. Or follow the guide: cat VPS_DEPLOYMENT_GUIDE.md"
echo ""

