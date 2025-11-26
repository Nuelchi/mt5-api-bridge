//+------------------------------------------------------------------+
//|                                          MA_Crossover_Expert.mq5 |
//|                                         Expert MQL5 Programmer   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5 Programmer"
#property link      ""
#property version   "1.00"
#property strict

// --- Backwards compatibility for older MT5 builds (ensure filling constants exist)
#ifndef TRAINFLOW_FILLING_FOK
   #ifdef ORDER_FILLING_FOK
      #define TRAINFLOW_FILLING_FOK ORDER_FILLING_FOK
   #else
      #define TRAINFLOW_FILLING_FOK ((ENUM_ORDER_TYPE_FILLING)0)
   #endif
#endif

#ifndef TRAINFLOW_FILLING_IOC
   #ifdef ORDER_FILLING_IOC
      #define TRAINFLOW_FILLING_IOC ORDER_FILLING_IOC
   #else
      #define TRAINFLOW_FILLING_IOC ((ENUM_ORDER_TYPE_FILLING)1)
   #endif
#endif

#ifndef TRAINFLOW_FILLING_RETURN
   #ifdef ORDER_FILLING_RETURN
      #define TRAINFLOW_FILLING_RETURN ORDER_FILLING_RETURN
   #else
      #define TRAINFLOW_FILLING_RETURN ((ENUM_ORDER_TYPE_FILLING)2)
   #endif
#endif

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Input parameters
input group "=== Moving Average Settings ==="
input int FastMA_Period = 10;                    // Fast MA Period
input int SlowMA_Period = 30;                    // Slow MA Period
input ENUM_MA_METHOD MA_Method = MODE_EMA;       // MA Method
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE; // MA Applied Price

input group "=== Risk Management ==="
input double RiskPerTrade = 0.01;                // Risk Per Trade (% of balance)
input double MaxDailyLoss = 0.03;                // Max Daily Loss (% of balance)
input int MaxPositions = 3;                      // Maximum Open Positions

input group "=== Stop Loss & Take Profit ==="
input int StopLossPips = 50;                     // Stop Loss (pips)
input int TakeProfitPips = 100;                  // Take Profit (pips)
input double ATR_Multiplier_SL = 1.5;            // ATR Multiplier for SL
input double ATR_Multiplier_TP = 3.0;            // ATR Multiplier for TP
input bool UseATR = false;                       // Use ATR for SL/TP

input group "=== Trailing Stop ==="
input bool UseTrailingStop = true;               // Use Trailing Stop
input int TrailingStopPips = 20;                 // Trailing Stop (pips)
input int BreakEvenPips = 30;                    // Break Even (pips)

input group "=== Trading Settings ==="
input int MagicNumber = 123456;                  // Magic Number
input int Deviation = 10;                        // Slippage (points)
input double MaxSpreadPips = 3.0;                // Max Spread (pips)
input double MinLotSize = 0.01;                  // Minimum Lot Size
input double MaxLotSize = 100.0;                 // Maximum Lot Size

input group "=== ATR Settings ==="
input int ATR_Period = 14;                       // ATR Period

//--- Global variables
CTrade trade;
CPositionInfo positionInfo;
CAccountInfo accountInfo;
CSymbolInfo symbolInfo;

int fastMAHandle;
int slowMAHandle;
int atrHandle;

double fastMABuffer[];
double slowMABuffer[];
double atrBuffer[];

datetime lastBarTime = 0;
double dailyStartBalance = 0;
double dailyLoss = 0;
datetime lastDayCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize symbol info
   symbolInfo.Name(_Symbol);
   symbolInfo.Refresh();
   
   //--- Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Deviation);
   trade.SetTypeFilling(TRAINFLOW_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   //--- Check if FOK is not available, try IOC
   if(!symbolInfo.IsFillTypeAllowed(TRAINFLOW_FILLING_FOK))
   {
      trade.SetTypeFilling(TRAINFLOW_FILLING_IOC);
   }
   
   //--- Create Fast MA indicator
   fastMAHandle = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MA_Method, MA_Price);
   if(fastMAHandle == INVALID_HANDLE)
   {
      Print("Error creating Fast MA indicator: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- Create Slow MA indicator
   slowMAHandle = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MA_Method, MA_Price);
   if(slowMAHandle == INVALID_HANDLE)
   {
      Print("Error creating Slow MA indicator: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- Create ATR indicator
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- Set array as series
   ArraySetAsSeries(fastMABuffer, true);
   ArraySetAsSeries(slowMABuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   
   //--- Initialize daily loss tracking
   dailyStartBalance = accountInfo.Balance();
   lastDayCheck = TimeCurrent();
   
   Print("Expert Advisor initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(fastMAHandle != INVALID_HANDLE)
      IndicatorRelease(fastMAHandle);
   if(slowMAHandle != INVALID_HANDLE)
      IndicatorRelease(slowMAHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   
   Print("Expert Advisor deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;
   
   //--- Update symbol info
   if(!symbolInfo.Refresh())
   {
      Print("Error refreshing symbol info");
      return;
   }
   
   //--- Check daily loss limit
   CheckDailyLoss();
   if(dailyLoss >= MaxDailyLoss * dailyStartBalance)
   {
      Print("Daily loss limit reached. Trading stopped for today.");
      return;
   }
   
   //--- Check spread
   if(!CheckSpread())
   {
      Print("Spread too high: ", GetCurrentSpreadPips(), " pips");
      return;
   }
   
   //--- Copy indicator buffers
   if(CopyBuffer(fastMAHandle, 0, 0, 3, fastMABuffer) <= 0)
   {
      Print("Error copying Fast MA buffer: ", GetLastError());
      return;
   }
   
   if(CopyBuffer(slowMAHandle, 0, 0, 3, slowMABuffer) <= 0)
   {
      Print("Error copying Slow MA buffer: ", GetLastError());
      return;
   }
   
   if(CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) <= 0)
   {
      Print("Error copying ATR buffer: ", GetLastError());
      return;
   }
   
   //--- Manage open positions (trailing stop, break even)
   ManagePositions();
   
   //--- Check for trading signals
   int signal = GetTradeSignal();
   
   if(signal == 1) // Buy signal
   {
      if(CountPositions() < MaxPositions && !HasPosition(POSITION_TYPE_BUY))
      {
         OpenBuyPosition();
      }
   }
   else if(signal == -1) // Sell signal
   {
      if(CountPositions() < MaxPositions && !HasPosition(POSITION_TYPE_SELL))
      {
         OpenSellPosition();
      }
   }
}

//+------------------------------------------------------------------+
//| Get trade signal                                                  |
//+------------------------------------------------------------------+
int GetTradeSignal()
{
   //--- Check if we have enough data
   if(ArraySize(fastMABuffer) < 3 || ArraySize(slowMABuffer) < 3)
      return 0;
   
   //--- Current values
   double fastMA_Current = fastMABuffer[0];
   double slowMA_Current = slowMABuffer[0];
   
   //--- Previous values
   double fastMA_Previous = fastMABuffer[1];
   double slowMA_Previous = slowMABuffer[1];
   
   //--- Buy signal: Fast MA crosses above Slow MA
   if(fastMA_Previous <= slowMA_Previous && fastMA_Current > slowMA_Current)
   {
      return 1;
   }
   
   //--- Sell signal: Fast MA crosses below Slow MA
   if(fastMA_Previous >= slowMA_Previous && fastMA_Current < slowMA_Current)
   {
      return -1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                 |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   
   //--- Calculate pip value
   int digits = (int)symbolInfo.Digits();
   double pipValue = (digits == 3 || digits == 5) ? symbolInfo.Point() * 10 : symbolInfo.Point();
   
   //--- Calculate Stop Loss and Take Profit
   double sl, tp;
   
   if(UseATR && ArraySize(atrBuffer) > 0)
   {
      double atr = atrBuffer[0];
      sl = ask - (atr * ATR_Multiplier_SL);
      tp = ask + (atr * ATR_Multiplier_TP);
   }
   else
   {
      sl = ask - (StopLossPips * pipValue);
      tp = ask + (TakeProfitPips * pipValue);
   }
   
   //--- Normalize prices
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   //--- Calculate lot size
   double lotSize = CalculateLotSize(ask, sl);
   
   if(lotSize < MinLotSize || lotSize > MaxLotSize)
   {
      Print("Invalid lot size: ", lotSize);
      return;
   }
   
   //--- Open position
   if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "MA Crossover Buy"))
   {
      Print("Buy position opened successfully. Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("Error opening Buy position: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Open Sell Position                                                |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   
   //--- Calculate pip value
   int digits = (int)symbolInfo.Digits();
   double pipValue = (digits == 3 || digits == 5) ? symbolInfo.Point() * 10 : symbolInfo.Point();
   
   //--- Calculate Stop Loss and Take Profit
   double sl, tp;
   
   if(UseATR && ArraySize(atrBuffer) > 0)
   {
      double atr = atrBuffer[0];
      sl = bid + (atr * ATR_Multiplier_SL);
      tp = bid - (atr * ATR_Multiplier_TP);
   }
   else
   {
      sl = bid + (StopLossPips * pipValue);
      tp = bid - (TakeProfitPips * pipValue);
   }
   
   //--- Normalize prices
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   //--- Calculate lot size
   double lotSize = CalculateLotSize(bid, sl);
   
   if(lotSize < MinLotSize || lotSize > MaxLotSize)
   {
      Print("Invalid lot size: ", lotSize);
      return;
   }
   
   //--- Open position
   if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "MA Crossover Sell"))
   {
      Print("Sell position opened successfully. Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("Error opening Sell position: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLossPrice)
{
   double riskAmount = accountInfo.Balance() * RiskPerTrade;
   double stopLossDistance = MathAbs(entryPrice - stopLossPrice);
   
   if(stopLossDistance == 0)
   {
      Print("Stop loss distance is zero");
      return MinLotSize;
   }
   
   //--- Get tick size and tick value
   double tickSize = symbolInfo.TickSize();
   double tickValue = symbolInfo.TickValue();
   
   if(tickSize == 0 || tickValue == 0)
   {
      Print("Invalid tick size or tick value");
      return MinLotSize;
   }
   
   //--- Calculate lot size
   double lotSize = riskAmount / (stopLossDistance / tickSize * tickValue);
   
   //--- Normalize lot size
   double lotStep = symbolInfo.LotsStep();
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   //--- Apply limits
   double minLot = symbolInfo.LotsMin();
   double maxLot = symbolInfo.LotsMax();
   
   if(lotSize < minLot)
      lotSize = minLot;
   if(lotSize > maxLot)
      lotSize = maxLot;
   if(lotSize < MinLotSize)
      lotSize = MinLotSize;
   if(lotSize > MaxLotSize)
      lotSize = MaxLotSize;
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Manage open positions                                             |
//+------------------------------------------------------------------+
void ManagePositions()
{
   int digits = (int)symbolInfo.Digits();
   double pipValue = (digits == 3 || digits == 5) ? symbolInfo.Point() * 10 : symbolInfo.Point();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!positionInfo.SelectByIndex(i))
         continue;
      
      if(positionInfo.Symbol() != _Symbol || positionInfo.Magic() != MagicNumber)
         continue;
      
      double positionOpenPrice = positionInfo.PriceOpen();
      double currentSL = positionInfo.StopLoss();
      double currentTP = positionInfo.TakeProfit();
      ulong ticket = positionInfo.Ticket();
      
      if(positionInfo.Type() == POSITION_TYPE_BUY)
      {
         double currentPrice = symbolInfo.Bid();
         double profitPips = (currentPrice - positionOpenPrice) / pipValue;
         
         //--- Break even
         if(BreakEvenPips > 0 && profitPips >= BreakEvenPips)
         {
            if(currentSL < positionOpenPrice)
            {
               double newSL = NormalizeDouble(positionOpenPrice + (pipValue * 1), digits);
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("Position moved to break even. Ticket: ", ticket);
               }
            }
         }
         
         //--- Trailing stop
         if(UseTrailingStop && TrailingStopPips > 0 && profitPips >= TrailingStopPips)
         {
            double newSL = NormalizeDouble(currentPrice - (TrailingStopPips * pipValue), digits);
            if(newSL > currentSL)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("Trailing stop updated. Ticket: ", ticket, " New SL: ", newSL);
               }
            }
         }
      }
      else if(positionInfo.Type() == POSITION_TYPE_SELL)
      {
         double currentPrice = symbolInfo.Ask();
         double profitPips = (positionOpenPrice - currentPrice) / pipValue;
         
         //--- Break even
         if(BreakEvenPips > 0 && profitPips >= BreakEvenPips)
         {
            if(currentSL > positionOpenPrice || currentSL == 0)
            {
               double newSL = NormalizeDouble(positionOpenPrice - (pipValue * 1), digits);
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("Position moved to break even. Ticket: ", ticket);
               }
            }
         }
         
         //--- Trailing stop
         if(UseTrailingStop && TrailingStopPips > 0 && profitPips >= TrailingStopPips)
         {
            double newSL = NormalizeDouble(currentPrice + (TrailingStopPips * pipValue), digits);
            if(newSL < currentSL || currentSL == 0)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("Trailing stop updated. Ticket: ", ticket, " New SL: ", newSL);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count open positions                                              |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!positionInfo.SelectByIndex(i))
         continue;
      
      if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if position type exists                                     |
//+------------------------------------------------------------------+
bool HasPosition(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!positionInfo.SelectByIndex(i))
         continue;
      
      if(positionInfo.Symbol() == _Symbol && 
         positionInfo.Magic() == MagicNumber && 
         positionInfo.Type() == posType)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check spread                                                       |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   double currentSpread = GetCurrentSpreadPips();
   return (currentSpread <= MaxSpreadPips);
}

//+------------------------------------------------------------------+
//| Get current spread in pips                                        |
//+------------------------------------------------------------------+
double GetCurrentSpreadPips()
{
   int digits = (int)symbolInfo.Digits();
   double pipValue = (digits == 3 || digits == 5) ? symbolInfo.Point() * 10 : symbolInfo.Point();
   
   double spread = symbolInfo.Ask() - symbolInfo.Bid();
   return spread / pipValue;
}

//+------------------------------------------------------------------+
//| Check daily loss                                                  |
//+------------------------------------------------------------------+
void CheckDailyLoss()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   MqlDateTime lastCheckTime;
   TimeToStruct(lastDayCheck, lastCheckTime);
   
   //--- Reset daily loss at start of new day
   if(currentTime.day != lastCheckTime.day)
   {
      dailyStartBalance = accountInfo.Balance();
      dailyLoss = 0;
      lastDayCheck = TimeCurrent();
      Print("New trading day. Daily loss reset. Starting balance: ", dailyStartBalance);
   }
   
   //--- Update daily loss
   dailyLoss = dailyStartBalance - accountInfo.Equity();
   
   if(dailyLoss < 0)
      dailyLoss = 0;
}

//+------------------------------------------------------------------+


