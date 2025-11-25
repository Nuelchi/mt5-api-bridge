#!/bin/bash
# Quick test and setup script

set -e

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "🧪 Testing MT5 Connection"
echo "=========================="
echo ""

# Test connection
python3 -c "
from mt5linux import MetaTrader5
import sys

try:
    print('Connecting to RPyC server...')
    mt5 = MetaTrader5(host='localhost', port=8001)
    print('✅ Connected to RPyC server')
    
    print('Getting account info...')
    account = mt5.account_info()
    
    if account:
        print(f'✅ MT5 is logged in!')
        print(f'   Account: {account.login}')
        print(f'   Server: {account.server}')
        print(f'   Balance: {account.balance}')
        print(f'   Equity: {account.equity}')
        sys.exit(0)
    else:
        print('⚠️  MT5 Terminal is running but not logged in')
        print('   Please log in to MT5 Terminal:')
        print('   Server: MetaQuotes-Demo')
        print('   Login: 5042856355')
        print('   Password: V!QzRxQ7')
        sys.exit(1)
        
except ConnectionRefusedError:
    print('❌ Cannot connect to RPyC server on port 8001')
    print('   Check: systemctl status mt5-rpyc')
    sys.exit(1)
except Exception as e:
    print(f'❌ Error: {e}')
    print('   MT5 Terminal may not be logged in')
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Connection test passed!"
    echo ""
    echo "🚀 Running complete setup..."
    echo ""
    chmod +x COMPLETE_SETUP.sh
    ./COMPLETE_SETUP.sh
else
    echo ""
    echo "⚠️  Please log in to MT5 Terminal first, then run:"
    echo "   ./TEST_AND_SETUP.sh"
fi



