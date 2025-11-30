#!/bin/bash
# Quick script to start noVNC on port 3000 (matching Docker setup)

echo "🔄 Starting noVNC on port 3000..."

# Kill any existing websockify/novnc on port 3000 or 6080
pkill -f "websockify.*3000" 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true
pkill -f "novnc.*3000" 2>/dev/null || true
sleep 2

if [ -d "/opt/noVNC" ]; then
    cd /opt/noVNC
    
    # Try websockify first (more reliable)
    if [ -d "/opt/noVNC/websockify" ]; then
        cd /opt/noVNC/websockify
        echo "   Starting websockify on port 3000..."
        python3 websockify.py --web=/opt/noVNC --target-config=/dev/null 3000 localhost:5900 > /tmp/websockify.log 2>&1 &
        sleep 3
        
        if pgrep -f "websockify.*3000" > /dev/null; then
            echo "   ✅ websockify started on port 3000"
            echo ""
            echo "🌐 Web VNC accessible at: http://147.182.206.223:3000/vnc.html"
            echo "   Or: http://$(hostname -I | awk '{print $1}'):3000/vnc.html"
            exit 0
        else
            echo "   ⚠️  websockify failed to start (check /tmp/websockify.log)"
        fi
    fi
    
    # Fallback to novnc_proxy
    cd /opt/noVNC
    echo "   Trying novnc_proxy..."
    ./utils/novnc_proxy --vnc localhost:5900 --listen 3000 > /tmp/novnc.log 2>&1 &
    sleep 3
    
    if pgrep -f "novnc_proxy.*3000" > /dev/null; then
        echo "   ✅ noVNC started on port 3000"
        echo ""
        echo "🌐 Web VNC accessible at: http://147.182.206.223:3000/vnc.html"
        exit 0
    else
        echo "   ❌ Failed to start noVNC (check /tmp/novnc.log)"
        exit 1
    fi
else
    echo "   ❌ noVNC not found at /opt/noVNC"
    echo "   Run REBUILD_FROM_SCRATCH.sh first to install noVNC"
    exit 1
fi

