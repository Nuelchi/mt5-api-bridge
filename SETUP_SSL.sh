#!/bin/bash
# Set up SSL certificate with Let's Encrypt

set -e

DOMAIN="trade.trainflow.dev"
EMAIL="55emmachi@gmail.com"

echo "🔒 Setting up SSL Certificate"
echo "============================="
echo ""

# Check if certbot is installed
if ! command -v certbot >/dev/null 2>&1; then
    echo "📦 Installing certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Check if Nginx is configured
if [ ! -f "/etc/nginx/sites-available/mt5-api" ]; then
    echo "⚠️  Nginx not configured yet. Running NGINX_CONFIG.sh first..."
    cd /opt/mt5-api-bridge
    ./NGINX_CONFIG.sh
fi

# Test Nginx configuration
echo "🧪 Testing Nginx configuration..."
nginx -t || {
    echo "❌ Nginx configuration has errors"
    exit 1
}

# Request SSL certificate
echo ""
echo "📜 Requesting SSL certificate from Let's Encrypt..."
echo "   Domain: ${DOMAIN}"
echo "   Email: ${EMAIL}"
echo ""

certbot --nginx \
    -d ${DOMAIN} \
    --email ${EMAIL} \
    --agree-tos \
    --non-interactive \
    --redirect || {
    echo ""
    echo "⚠️  SSL certificate request failed"
    echo "   This might be because:"
    echo "   1. Domain DNS is not pointing to this server"
    echo "   2. Port 80 is not accessible"
    echo "   3. Domain is already has a certificate"
    echo ""
    echo "   Check DNS: nslookup ${DOMAIN}"
    echo "   Check port: ss -tlnp | grep :80"
    exit 1
}

# Reload Nginx
echo ""
echo "🔄 Reloading Nginx..."
systemctl reload nginx

# Test SSL
echo ""
echo "🧪 Testing SSL..."
sleep 2
if curl -k -s https://${DOMAIN}/health >/dev/null 2>&1; then
    echo "✅ SSL is working!"
    echo "   Test: curl https://${DOMAIN}/health"
else
    echo "⚠️  SSL test failed, but certificate may still be valid"
fi

echo ""
echo "✅ SSL Setup Complete!"
echo ""
echo "📋 Certificate Info:"
echo "   Domain: ${DOMAIN}"
echo "   Certificate: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "   Private Key: /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
echo ""
echo "🔄 Auto-renewal: Certbot will auto-renew certificates"
echo "   Check renewal: certbot renew --dry-run"
echo ""



