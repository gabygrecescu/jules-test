//+------------------------------------------------------------------+
//|                                       MegaPower_Dashboard.mq5 |
//|                                                      Jules AI     |
//|                                     github.com/sweep-ai/jules |
//+------------------------------------------------------------------+
#property copyright "Jules AI"
#property link      "https://github.com/sweep-ai/jules"
#property version   "1.00"
#property strict

//--- Include
#include <Trade/Trade.mqh>

//--- EA Inputs
input group           "Dashboard Settings"
input bool            dashOn = true;                // Dashboard On / Off
input int             dashDist = 93;                // Dashboard X Offset
input int             dashYOffset = 20;             // Dashboard Y Offset
input color           dashTextColor = C'0x00,0xC8,0xFF'; // Text Color
input color           dashBgColor = C'0x00,0x00,0x00';   // Background Color
input string          dashFont = "Courier New";     // Font
input int             dashFontSize = 8;             // Font Size
input bool            useEmojis = true;              // Use Emojis for Trend

//--- Global Variables
// Handles
int dash_atr_handle;
int dash_rsi_handle;
int dash_ema_handle;
int dash_mtf_sma_handles[10];
ENUM_TIMEFRAMES dash_timeframes[10] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, (ENUM_TIMEFRAMES)120, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};

// Object Names
string g_bg_name;
string g_text_name;

// Function Prototypes
void UpdateDashboard();
double SMAOnArray(const double &arr[], int period, int start_index=0);
double StdDevOnArray(const double &arr[], int period, int start_index=0);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Generate object names
    g_bg_name = "MEGA_BG_" + (string)ChartID();
    g_text_name = "MEGA_TXT_" + (string)ChartID();

    //--- Initialize Indicator Handles
    dash_atr_handle = iATR(_Symbol, _Period, 14);
    dash_rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    dash_ema_handle = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
    for(int i=0; i<10; i++)
    {
        dash_mtf_sma_handles[i] = iMA(_Symbol, dash_timeframes[i], 50, 0, MODE_SMA, PRICE_CLOSE);
        if(dash_mtf_sma_handles[i] == INVALID_HANDLE)
        {
            Print("Error creating MTF SMA handle for ", EnumToString(dash_timeframes[i]));
        }
    }

    //--- Set up the timer
    EventSetTimer(2);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Kill the timer
    EventKillTimer();

    //--- Release indicator handles
    IndicatorRelease(dash_atr_handle);
    IndicatorRelease(dash_rsi_handle);
    IndicatorRelease(dash_ema_handle);
    for(int i=0; i<10; i++) IndicatorRelease(dash_mtf_sma_handles[i]);

    //--- Delete graphical objects
    ObjectDelete(0, g_bg_name);
    ObjectDelete(0, g_text_name);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Main Dashboard Update Function                                   |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!dashOn)
     {
      ObjectDelete(0, g_bg_name);
      ObjectDelete(0, g_text_name);
      return;
     }

   // --- Calculations ---
   // Volatility
   double atr_buffer[20];
   double percentVol = 0;
   if(CopyBuffer(dash_atr_handle, 0, 0, 20, atr_buffer) == 20)
     {
      ArraySetAsSeries(atr_buffer, true);
      double sma_atr_val = SMAOnArray(atr_buffer, 20);
      double stdev_atr_val = StdDevOnArray(atr_buffer, 20);
      double topAtrDev = sma_atr_val + 2 * stdev_atr_val;
      double bottomAtrDev = sma_atr_val - 2 * stdev_atr_val;
      if(topAtrDev != bottomAtrDev)
        {
         double calcDev = (atr_buffer[0] - bottomAtrDev) / (topAtrDev - bottomAtrDev);
         percentVol = 40 * calcDev + 30;
        }
     }

   // Volume
   long volume_arr[1];
   long volumeDash = 0;
   if(CopyTickVolume(_Symbol, _Period, 0, 1, volume_arr) > 0) volumeDash = volume_arr[0];


   // RSI
   double rsi_buffer[1];
   double rsiDash = 0;
   if(CopyBuffer(dash_rsi_handle, 0, 0, 1, rsi_buffer) > 0) rsiDash = rsi_buffer[0];

   // Sentiment
   double ema_buffer[3];
   string totalSentTxt = "Flat";
   if(CopyBuffer(dash_ema_handle, 0, 0, 3, ema_buffer) > 0)
     {
      ArraySetAsSeries(ema_buffer, true);
      if(ema_buffer[0] > ema_buffer[2]) totalSentTxt = "Bullish";
      else if(ema_buffer[0] < ema_buffer[2]) totalSentTxt = "Bearish";
     }

   // Trend Panel
   string trends[10];
   string timeframe_names[10] = {"1m", "5m", "15m", "30m", "1H", "2H", "4H", "Daily", "Weekly", "Monthly"};
   for(int t=0; t<10; t++)
     {
      double sma_buffer[2];
      if(CopyBuffer(dash_mtf_sma_handles[t], 0, 0, 2, sma_buffer) > 0)
        {
         ArraySetAsSeries(sma_buffer, true);
         if(useEmojis)
            trends[t] = (sma_buffer[0] > sma_buffer[1]) ? "🟢" : "🔴";
         else
            trends[t] = (sma_buffer[0] > sma_buffer[1]) ? "UP" : "DN";
        }
      else
        {
         trends[t] = "⚪";
        }
     }

   // --- Drawing ---
   string text = "☁️ TABLETA MEGA POWER V3  ☁️\n";
   text += "━━━━━━━━━━━━━━━━━\n";
   text += "           💵 informacion de mercado 💵\n";
   text += "━━━━━━━━━━━━━━━━━\n";
   text += "🟡   Volatilidad                     | " + DoubleToString(percentVol, 2) + "%\n";
   text += "🟡 Volumen                           | " + (string)volumeDash + "\n";
   text += "🟡 RSI                                           | " + DoubleToString(rsiDash, 2) + "\n";
   text += "🟡 Sentimiento mercado | " + totalSentTxt + "\n";
   text += "━━━━━━━━━━━━━━━━━\n";
   text += "               📈 Trend Panel 📉\n";
   text += "━━━━━━━━━━━━━━━━━\n";
   text += "     1 Minute | " + trends[0] + "         2 Hour | " + trends[5] + "\n";
   text += "     5 Minute | " + trends[1] + "         4 Hour | " + trends[6] + "\n";
   text += "        15 Minute | " + trends[2] + "         Weekly | " + trends[7] + "\n";
   text += "        30 Minute | " + trends[3] + "       Monthly |     " + trends[8] + "\n";
   text += "        1 Hour | " + trends[4] + "                Daily | " + trends[9] + "\n";
   text += "━━━━━━━━━━━━━━━━━\n";
   text += "                     🔱CRIPTOM4N 🔱";

   if(ObjectFind(0, g_text_name) < 0)
     {
      ObjectCreate(0, g_text_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_text_name, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSetInteger(0, g_text_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, g_text_name, OBJPROP_XDISTANCE, dashDist);
      ObjectSetInteger(0, g_text_name, OBJPROP_YDISTANCE, dashYOffset);
      ObjectSetString(0, g_text_name, OBJPROP_FONT, dashFont);
      ObjectSetInteger(0, g_text_name, OBJPROP_FONTSIZE, dashFontSize);
      ObjectSetInteger(0, g_text_name, OBJPROP_COLOR, dashTextColor);
      ObjectSetInteger(0, g_text_name, OBJPROP_BACK, false);
     }
   ObjectSetString(0, g_text_name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
double SMAOnArray(const double &arr[], int period, int start_index=0)
{
    double sum = 0;
    int size = MathMin(period, ArraySize(arr) - start_index);
    if(size <= 0) return 0;
    for(int i=0; i<size; i++) sum += arr[start_index + i];
    return sum / size;
}

double StdDevOnArray(const double &arr[], int period, int start_index=0)
{
    int size = MathMin(period, ArraySize(arr) - start_index);
    if(size <= 0) return 0;

    double mean = SMAOnArray(arr, size, start_index);
    double sum_sq_diff = 0;
    for(int i=0; i<size; i++)
    {
        sum_sq_diff += MathPow(arr[start_index + i] - mean, 2);
    }
    return MathSqrt(sum_sq_diff / size);
}
