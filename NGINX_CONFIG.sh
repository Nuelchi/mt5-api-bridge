#!/bin/bash
# Configure Nginx for MT5 API Bridge

set -e

DOMAIN="trade.trainflow.dev"
UPSTREAM_PORT=8001

echo "🔧 Configuring Nginx for MT5 API Bridge"
echo "========================================"
echo ""

# Create Nginx configuration
cat > /etc/nginx/sites-available/mt5-api <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    # Logging
    access_log /var/log/nginx/mt5-api-access.log;
    error_log /var/log/nginx/mt5-api-error.log;

    # Client body size (for large requests)
    client_max_body_size 10M;

    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:${UPSTREAM_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint (no auth required)
    location /health {
        proxy_pass http://127.0.0.1:${UPSTREAM_PORT}/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/mt5-api /etc/nginx/sites-enabled/mt5-api

# Remove default site if exists
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "🧪 Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration is valid"
    systemctl reload nginx
    echo "✅ Nginx reloaded"
else
    echo "❌ Nginx configuration has errors"
    exit 1
fi

echo ""
echo "✅ Nginx configured successfully!"
echo ""
echo "🔗 Next: Set up SSL with Let's Encrypt"
echo "   Run: certbot --nginx -d ${DOMAIN} --email 55emmachi@gmail.com --agree-tos --non-interactive"
echo ""

