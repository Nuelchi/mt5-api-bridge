"""
Trade Journal Logger for MT5 Bridge
Automatically logs closed MT5 positions to the trade journal
"""

import logging
from typing import Dict, Any, Optional
from datetime import datetime
from database.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)


async def log_closed_position_to_journal(
    user_id: str,
    account_id: str,
    position_data: Dict[str, Any],
    close_result: Dict[str, Any]
) -> Optional[str]:
    """
    Log a closed MT5 position to the trade journal
    
    Args:
        user_id: Supabase user ID
        account_id: MT5 account ID
        position_data: Original position data before closing
        close_result: Result from closing the position
        
    Returns:
        Trade journal entry ID if successful, None otherwise
    """
    try:
        supabase = get_supabase_client()
        if not supabase:
            logger.warning("Supabase client not available, skipping trade journal logging")
            return None
        
        # Extract position information
        entry_price = float(position_data.get('price_open', 0))
        exit_price = float(close_result.get('price', entry_price))
        volume = float(position_data.get('volume', 0))
        symbol = position_data.get('symbol', '')
        trade_type = 'BUY' if position_data.get('type') == 0 else 'SELL'  # 0 = BUY, 1 = SELL
        profit = float(position_data.get('profit', 0))
        
        # Calculate P&L percentage
        pnl_percent = 0.0
        if entry_price > 0 and volume > 0:
            price_diff = exit_price - entry_price if trade_type == 'BUY' else entry_price - exit_price
            pnl_percent = (price_diff / entry_price) * 100
        
        # Get stop loss and take profit
        stop_loss = float(position_data.get('sl', 0)) if position_data.get('sl', 0) > 0 else None
        take_profit = float(position_data.get('tp', 0)) if position_data.get('tp', 0) > 0 else None
        
        # Determine exit reason
        exit_reason = 'MANUAL_CLOSE'
        if stop_loss and exit_price <= stop_loss:
            exit_reason = 'STOP_LOSS'
        elif take_profit and exit_price >= take_profit:
            exit_reason = 'TAKE_PROFIT'
        
        # Convert timestamps
        entry_time = datetime.fromtimestamp(position_data.get('time_open', 0))
        exit_time = datetime.now()
        
        # Create trade journal entry
        trade_data = {
            'user_id': user_id,
            'account_id': account_id,
            'strategy_id': 'manual_trade',  # Default for manual trades
            'deployment_id': 'mt5_manual',  # Default for manual trades
            'trade_type': trade_type,
            'symbol': symbol,
            'entry_price': entry_price,
            'exit_price': exit_price,
            'stop_loss': stop_loss,
            'take_profit': take_profit,
            'position_size': volume,
            'pnl': profit,
            'pnl_percent': pnl_percent,
            'status': 'CLOSED',
            'entry_time': entry_time.isoformat(),
            'exit_time': exit_time.isoformat(),
            'exit_reason': exit_reason,
            'mt5_ticket': int(position_data.get('ticket', 0))
        }
        
        # Insert into trade_journal table
        result = supabase.table('trade_journal').insert(trade_data).execute()
        
        if result.data and len(result.data) > 0:
            trade_journal_id = result.data[0].get('id')
            logger.info(f"✅ Trade journal entry created: {trade_journal_id} for MT5 ticket {position_data.get('ticket')}")
            return trade_journal_id
        else:
            logger.error("Failed to create trade journal entry - no data returned")
            return None
            
    except Exception as e:
        logger.error(f"Error logging closed position to trade journal: {e}", exc_info=True)
        # Don't fail the close operation if journal logging fails
        return None

