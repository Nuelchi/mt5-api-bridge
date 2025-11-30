#!/bin/bash
# Update Nginx timeouts to prevent 504 Gateway Timeout errors

echo "🔧 Updating Nginx Timeouts"
echo "=========================="
echo ""

NGINX_CONFIG="/etc/nginx/sites-available/mt5-api"

if [ ! -f "$NGINX_CONFIG" ]; then
    echo "❌ Nginx config not found at: $NGINX_CONFIG"
    echo "   Run ./NGINX_CONFIG.sh first"
    exit 1
fi

echo "[1/2] Updating Nginx configuration..."
echo "   Current config: $NGINX_CONFIG"
echo ""

# Backup current config
cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created"

# Update timeouts to 120 seconds
sed -i 's/proxy_connect_timeout [0-9]*s/proxy_connect_timeout 120s/g' "$NGINX_CONFIG"
sed -i 's/proxy_send_timeout [0-9]*s/proxy_send_timeout 120s/g' "$NGINX_CONFIG"
sed -i 's/proxy_read_timeout [0-9]*s/proxy_read_timeout 120s/g' "$NGINX_CONFIG"

# If timeouts don't exist, add them
if ! grep -q "proxy_connect_timeout" "$NGINX_CONFIG"; then
    # Find the location block and add timeouts
    sed -i '/proxy_set_header X-Forwarded-Port/a\        \n        # Timeouts\n        proxy_connect_timeout 120s;\n        proxy_send_timeout 120s;\n        proxy_read_timeout 120s;' "$NGINX_CONFIG"
fi

echo "✅ Timeouts updated to 120 seconds"
echo ""

# Test configuration
echo "[2/2] Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration is valid"
    systemctl reload nginx
    echo "✅ Nginx reloaded with new timeout settings"
    echo ""
    echo "📋 Updated timeouts:"
    grep -E "proxy_.*_timeout" "$NGINX_CONFIG" || echo "   (Timeouts not found in config)"
else
    echo "❌ Nginx configuration has errors"
    echo "   Restoring backup..."
    mv "${NGINX_CONFIG}.backup."* "$NGINX_CONFIG" 2>/dev/null || true
    exit 1
fi
echo ""

