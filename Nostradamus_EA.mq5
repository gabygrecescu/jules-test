//+------------------------------------------------------------------+
//|                                             Nostradamus_EA.mq5 |
//|                                                     Jules AI     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Jules AI"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- EA Inputs
enum ENUM_VOLUME_METHOD
  {
   VOL_METHOD_FIXED_LOT, // Fixed Lot
   VOL_METHOD_RISK_PERC  // % Risk of Equity
  };

input group           "Trade Management"
input double          RiskPercent = 1.0; // SL as % of Account Equity
input ENUM_VOLUME_METHOD VolumeMethod = VOL_METHOD_RISK_PERC; // Lot Sizing Method
input double          FixedLotSize = 0.01; // Fixed Lot Size
input int             BreakoutOffsetPoints = 20; // Breakout offset in points
input int             SL_Points = 200; // SL distance in points for Risk % Mode

//--- Global Variables
CTrade trade;
double g_prev_high = 0;
double g_prev_low = 0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Manage any open trades first
   ManageOpenTrades();

//--- New bar detection and breakout level setting
   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LAST_BAR_DATE);
   if(current_bar_time != last_bar_time)
     {
      // It's a new bar, get the high/low of the previous bar (index 1)
      double prev_high[1], prev_low[1];
      if(CopyHigh(_Symbol, _Period, 1, 1, prev_high) > 0 && CopyLow(_Symbol, _Period, 1, 1, prev_low) > 0)
        {
         g_prev_high = prev_high[0];
         g_prev_low = prev_low[0];
        }
      last_bar_time = current_bar_time;
     }

//--- Check for entry signals on every tick
   if(g_prev_high == 0 || g_prev_low == 0) return; // Wait until we have levels

   // Check if a position is already open for this symbol
   if(PositionSelect(_Symbol))
     {
      return; // A position is open, do not look for new signals.
     }

   // Define breakout levels
   double buy_trigger_price = g_prev_high + BreakoutOffsetPoints * _Point;
   double sell_trigger_price = g_prev_low - BreakoutOffsetPoints * _Point;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check for Buy breakout
   if(ask > buy_trigger_price)
     {
      TradeParameters params = CalculateTradeParameters(ORDER_TYPE_BUY, ask);
      if(params.lot_size > 0)
        {
         trade.Buy(params.lot_size, _Symbol, ask, params.sl, params.tp1, "Buy Breakout");
        }
      g_prev_high = 0; g_prev_low = 0; // Reset levels to prevent re-entry on same breakout
     }
   // Check for Sell breakout
   else if(bid < sell_trigger_price)
     {
      TradeParameters params = CalculateTradeParameters(ORDER_TYPE_SELL, bid);
      if(params.lot_size > 0)
        {
         trade.Sell(params.lot_size, _Symbol, bid, params.sl, params.tp1, "Sell Breakout");
        }
      g_prev_high = 0; g_prev_low = 0; // Reset levels to prevent re-entry on same breakout
     }
  }
//+------------------------------------------------------------------+
//| Trade Execution & Management Functions                           |
//+------------------------------------------------------------------+

// --- Struct to hold calculated trade parameters ---
struct TradeParameters
{
   double lot_size;
   double sl;
   double tp1;
   double tp2;
   double tp3;
};

// --- Main calculation function for SL, Lot Size, and TPs ---
TradeParameters CalculateTradeParameters(ENUM_ORDER_TYPE trade_type, double entry_price)
{
    TradeParameters params;
    params.lot_size = 0;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equity_risk = equity * (RiskPercent / 100.0);
    double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * _Point;

    if(point_value == 0) return params;

    // --- Calculate SL and Lot Size based on Volume Method ---
    if(VolumeMethod == VOL_METHOD_FIXED_LOT)
    {
        params.lot_size = FixedLotSize;
        double sl_points = equity_risk / (params.lot_size * point_value);
        if(trade_type == ORDER_TYPE_BUY)
            params.sl = entry_price - sl_points * _Point;
        else
            params.sl = entry_price + sl_points * _Point;
    }
    else // VOL_METHOD_RISK_PERC
    {
        double sl_points = SL_Points;
        params.lot_size = equity_risk / (sl_points * point_value);
        if(trade_type == ORDER_TYPE_BUY)
            params.sl = entry_price - sl_points * _Point;
        else
            params.sl = entry_price + sl_points * _Point;
    }

    // --- Normalize Lot and SL ---
    double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    params.lot_size = MathFloor(params.lot_size / vol_step) * vol_step;

    double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    if(params.lot_size < min_vol) params.lot_size = min_vol;
    if(params.lot_size > max_vol) params.lot_size = max_vol;

    double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if(trade_type == ORDER_TYPE_BUY)
        params.sl = NormalizeDouble(MathMin(entry_price - stop_level, params.sl), _Digits);
    else
        params.sl = NormalizeDouble(MathMax(entry_price + stop_level, params.sl), _Digits);

    // --- Calculate TPs based on final SL ---
    double R = MathAbs(entry_price - params.sl);
    if(trade_type == ORDER_TYPE_BUY)
    {
        params.tp1 = NormalizeDouble(entry_price + 1 * R, _Digits);
        params.tp2 = NormalizeDouble(entry_price + 2 * R, _Digits);
        params.tp3 = NormalizeDouble(entry_price + 3 * R, _Digits);
    }
    else // SELL
    {
        params.tp1 = NormalizeDouble(entry_price - 1 * R, _Digits);
        params.tp2 = NormalizeDouble(entry_price - 2 * R, _Digits);
        params.tp3 = NormalizeDouble(entry_price - 3 * R, _Digits);
    }

    return params;
}


// Function to manage open trades (SL trailing)
void ManageOpenTrades()
{
    if(!PositionSelect(_Symbol))
    {
        return; // No open position for this symbol
    }

    // Get position properties
    double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_tp = PositionGetDouble(POSITION_TP);
    long trade_type = PositionGetInteger(POSITION_TYPE);

    // Re-calculate R and TP levels for the current trade
    double R = MathAbs(entry_price - current_sl);
    if(R == 0) return;

    double tp1 = (trade_type == POSITION_TYPE_BUY) ? entry_price + 1 * R : entry_price - 1 * R;
    double tp2 = (trade_type == POSITION_TYPE_BUY) ? entry_price + 2 * R : entry_price - 2 * R;
    double tp3 = (trade_type == POSITION_TYPE_BUY) ? entry_price + 3 * R : entry_price - 3 * R;

    // Normalize
    tp1 = NormalizeDouble(tp1, _Digits);
    tp2 = NormalizeDouble(tp2, _Digits);
    tp3 = NormalizeDouble(tp3, _Digits);

    double new_sl = current_sl;
    double current_price = (trade_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Trailing SL logic
    if(trade_type == POSITION_TYPE_BUY)
    {
        if(current_price >= tp3 && current_sl < tp2) new_sl = tp2;
        else if(current_price >= tp2 && current_sl < tp1) new_sl = tp1;
        else if(current_price >= tp1 && current_sl < entry_price) new_sl = entry_price;
    }
    else // SELL
    {
        if(current_price <= tp3 && current_sl > tp2) new_sl = tp2;
        else if(current_price <= tp2 && current_sl > tp1) new_sl = tp1;
        else if(current_price <= tp1 && current_sl > entry_price) new_sl = entry_price;
    }

    // If SL has changed, modify the position
    if(new_sl != current_sl)
    {
        trade.PositionModify(_Symbol, new_sl, current_tp);
    }
}
