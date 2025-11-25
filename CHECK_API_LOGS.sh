#!/bin/bash
# Check API logs for filling mode attempts

echo "🔍 Checking API Logs for Filling Mode Issues"
echo "============================================="
echo ""

echo "[1/2] Recent API logs (last 50 lines)..."
echo "----------------------------------------"
journalctl -u mt5-api -n 50 --no-pager | grep -E "filling_mode|type_filling|Order|Trying order" || echo "No relevant logs found"
echo ""

echo "[2/2] Checking for error 10030..."
echo "--------------------------------"
journalctl -u mt5-api -n 100 --no-pager | grep -E "10030|Unsupported filling" || echo "No error 10030 found"
echo ""

echo "💡 To see live logs: journalctl -u mt5-api -f"

