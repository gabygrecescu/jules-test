//+------------------------------------------------------------------+
//|                                             Nostradamus_EA.mq5 |
//|                                                     Jules AI     |
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
input int             SL_Points = 200; // SL distance in points for Risk % Mode

//--- Global Variables
CTrade trade;
int    g_indicator_handle;
string g_indicator_path = "Indicators\\Nostradamus";

//--- Struct to hold calculated trade parameters
struct TradeParameters
{
   double lot_size;
   double sl;
   double tp1;
   double tp2;
   double tp3;
};

//--- Function Prototypes
TradeParameters CalculateTradeParameters(ENUM_ORDER_TYPE trade_type, double entry_price, double sl_price_base);
void ManageOpenTrades();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_indicator_handle = iCustom(_Symbol, _Period, g_indicator_path);
   if(g_indicator_handle == INVALID_HANDLE)
     {
      printf("Error creating indicator handle. Make sure Nostradamus.mq5 is in the Indicators folder. Error: %d", GetLastError());
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_indicator_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_indicator_handle);
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageOpenTrades();

   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LAST_BAR_DATE);
   if(current_bar_time == last_bar_time) return;
   last_bar_time = current_bar_time;

   if(PositionSelect(_Symbol)) return;

   double bull_signals[2], bear_signals[2];
   if(CopyBuffer(g_indicator_handle, 35, 1, 2, bull_signals)<=0 || CopyBuffer(g_indicator_handle, 36, 1, 2, bear_signals)<=0)
     {
      Print("Error copying indicator buffers.");
      return;
     }

   bool new_bull_signal = bull_signals[0] != EMPTY_VALUE;
   bool new_bear_signal = bear_signals[0] != EMPTY_VALUE;

   if(new_bull_signal)
     {
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      TradeParameters params = CalculateTradeParameters(ORDER_TYPE_BUY, entry_price, bull_signals[0]);
      if(params.lot_size > 0)
        {
         if(trade.Buy(params.lot_size, _Symbol, entry_price, 0, 0, "BUY"))
           {
            trade.PositionModify(_Symbol, params.sl, params.tp1);
           }
        }
     }
   else if(new_bear_signal)
     {
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      TradeParameters params = CalculateTradeParameters(ORDER_TYPE_SELL, entry_price, bear_signals[0]);
      if(params.lot_size > 0)
        {
         if(trade.Sell(params.lot_size, _Symbol, entry_price, 0, 0, "SELL"))
           {
            trade.PositionModify(_Symbol, params.sl, params.tp1);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Trade Execution & Management Functions                           |
//+------------------------------------------------------------------+
TradeParameters CalculateTradeParameters(ENUM_ORDER_TYPE trade_type, double entry_price, double sl_price_base)
{
    TradeParameters params;
    params.lot_size = 0;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equity_risk = equity * (RiskPercent / 100.0);
    double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * _Point;

    if(point_value == 0) return params;

    if(trade_type == ORDER_TYPE_BUY)
        params.sl = sl_price_base - SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    else
        params.sl = sl_price_base + SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

    double sl_distance_points = MathAbs(entry_price - params.sl) / _Point;

    if(VolumeMethod == VOL_METHOD_FIXED_LOT)
    {
        params.lot_size = FixedLotSize;
    }
    else // VOL_METHOD_RISK_PERC
    {
        if(sl_distance_points > 0)
            params.lot_size = (equity_risk / (sl_distance_points * point_value));
    }

    double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    params.lot_size = MathFloor(params.lot_size / vol_step) * vol_step;
    double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(params.lot_size < min_vol) params.lot_size = min_vol;

    double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if(trade_type == ORDER_TYPE_BUY)
        params.sl = NormalizeDouble(MathMin(entry_price - stop_level, params.sl), _Digits);
    else
        params.sl = NormalizeDouble(MathMax(entry_price + stop_level, params.sl), _Digits);

    double R = MathAbs(entry_price - params.sl);
    if(trade_type == ORDER_TYPE_BUY)
    {
        params.tp1 = NormalizeDouble(entry_price + 1 * R, _Digits);
        params.tp2 = NormalizeDouble(entry_price + 2 * R, _Digits);
        params.tp3 = NormalizeDouble(entry_price + 3 * R, _Digits);
    }
    else
    {
        params.tp1 = NormalizeDouble(entry_price - 1 * R, _Digits);
        params.tp2 = NormalizeDouble(entry_price - 2 * R, _Digits);
        params.tp3 = NormalizeDouble(entry_price - 3 * R, _Digits);
    }

    return params;
}

void ManageOpenTrades()
{
    if(!PositionSelect(_Symbol)) return;

    double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_tp = PositionGetDouble(POSITION_TP);
    long trade_type = PositionGetInteger(POSITION_TYPE);

    double R = MathAbs(entry_price - current_sl);
    if(R == 0) return;

    double tp1 = (trade_type == POSITION_TYPE_BUY) ? entry_price + 1 * R : entry_price - 1 * R;
    double tp2 = (trade_type == POSITION_TYPE_BUY) ? entry_price + 2 * R : entry_price - 2 * R;
    double tp3 = (trade_type == POSITION_TYPE_BUY) ? entry_price + 3 * R : entry_price - 3 * R;

    tp1 = NormalizeDouble(tp1, _Digits);
    tp2 = NormalizeDouble(tp2, _Digits);
    tp3 = NormalizeDouble(tp3, _Digits);

    double new_sl = current_sl;
    double current_price = (trade_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

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

    if(new_sl != current_sl)
    {
        trade.PositionModify(_Symbol, new_sl, current_tp);
    }
}
