//+------------------------------------------------------------------+
//|                                                 Nostradamus.mq5 |
//|                                                     Jules AI      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Jules AI"
#property link      ""
#property version   "1.00"
#property strict

#property indicator_chart_window
#property indicator_buffers 60 // Increased for new plots
#property indicator_plots   40 // Increased for new plots

//--- Plot Colors
#property indicator_color1 clrGreen,clrRed,clrWhite // Bar Colors: 0-Green, 1-Red, 2-White
#property indicator_color7 #1ab3d5, #e4ab1a // Colors for EMA Energy (Green, Red)
#property indicator_color8 #1ab3d5, #e4ab1a
#property indicator_color9 #1ab3d5, #e4ab1a
#property indicator_color10 #1ab3d5, #e4ab1a
#property indicator_color11 #1ab3d5, #e4ab1a
#property indicator_color12 #1ab3d5, #e4ab1a
#property indicator_color13 #1ab3d5, #e4ab1a
#property indicator_color14 #1ab3d5, #e4ab1a
#property indicator_color15 #1ab3d5, #e4ab1a
#property indicator_color16 #1ab3d5 // PSAR Color Green
#property indicator_color17 #e4ab1a // PSAR Color Red


//--- Plot definitions
#property indicator_label1 "Bar Colors"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2 "EMA"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3 "Low Wave EMA"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4 "High Wave EMA"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#property indicator_label5 "Centre Wave EMA"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6 "Fill Channel"
#property indicator_type6   DRAW_FILLING
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

#property indicator_label7 "SMA1"
#property indicator_type7   DRAW_COLOR_LINE
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1
// ... (properties for SMA2-SMA9 are implicitly defined by buffer settings)

#property indicator_label16 "PSAR"
#property indicator_type16  DRAW_CIRCLES
#property indicator_style16 STYLE_SOLID
#property indicator_width16 1

// KC Fills (plots 24-29)
#property indicator_label24 "KC Fill 1"
#property indicator_type24  DRAW_FILLING
#property indicator_color24 C'221,0,0'   // Red
#property indicator_label25 "KC Fill 2"
#property indicator_type25  DRAW_FILLING
#property indicator_color25 C'221,0,0'   // Red
#property indicator_label26 "KC Fill 3"
#property indicator_type26  DRAW_FILLING
#property indicator_color26 C'221,0,0'   // Red
#property indicator_label27 "KC Fill 4"
#property indicator_type27  DRAW_FILLING
#property indicator_color27 C'0,221,0'   // Green
#property indicator_label28 "KC Fill 5"
#property indicator_type28  DRAW_FILLING
#property indicator_color28 C'0,221,0'   // Green
#property indicator_label29 "KC Fill 6"
#property indicator_type29  DRAW_FILLING
#property indicator_color29 C'0,221,0'   // Green


//--- Include
#include <Arrays/ArrayObj.mqh>
#include <ChartObjects/ChartObjectsLines.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>

//--- Enums for string inputs
enum ENUM_SENSITIVITY
  {
   SENSITIVITY_LOW,    // Low
   SENSITIVITY_MEDIUM, // Medium
   SENSITIVITY_HIGH    // High
  };

enum ENUM_TP_METHOD
  {
   TP_METHOD_ATR,        // ATR
   TP_METHOD_PERCENTAGE, // PERCENTAGE
   TP_METHOD_PREDICTUM   // PREDICTUM
  };

enum ENUM_LINE_STYLE
  {
   STYLE_SOLID, // SOLID
   STYLE_DASH,  // DASHED
   STYLE_DOT    // DOTTED
  };

//--- Indicator Inputs

//--- Volume Profile
input group           "Volume Profile"
input int             bbars = 150;                  // Number of Bars
input int             cnum = 24;                    // Row Size
input double          percent = 100.0;              // Value Area Volume %
input color           poc_color = clrWhite;         // POC Color
input int             poc_width = 2;                // Width
input color           vup_color = clrBlue;          // Value Area Up
input color           vdown_color = clrOrange;      // Value Area Down
input color           up_color = clrBlue;           // UP Volume
input color           down_color = clrOrange;       // Down Volume
input bool            show_poc = false;             // Show POC Label

//--- Dashboard
input group           "Dashboard"
input bool            dashOn = true;                // Dashboard On / Off
input int             dashDist = 93;                // Dashboard Distance
input color           dashColor = clrBlack;         // Dashboard Color
input color           dashTextColor = C'0x00,0xC8,0xFF'; // Text Color

//--- EMA
input group           "EMA"
input ENUM_APPLIED_PRICE src = PRICE_CLOSE;         // Tipo EMA
input int             len = 200;                    // EMA 200
input color           ema_color = C'255,242,0';     // Color de la EMA

//--- EMA Wave (PAC)
input group           "EMA Wave (PAC)"
input bool            ShowPAC = false;              // Show EMA Wave
input bool            ShowBarColor = true;          // Show Coloured GRaB Candles
input int             PACLen = 34;                  // EMA Wave Length
input ENUM_APPLIED_PRICE src2 = PRICE_CLOSE;        // Source for Wave centre EMA

//--- AI Signals
input group           "AI Signals"
input ENUM_SENSITIVITY sensitivity = SENSITIVITY_LOW; // Sensitivity
input bool            suppRes = false;              // Support & Resistance
input bool            breaks = false;               // Breaks
input bool            usePsar = false;              // PSAR
input bool            emaEnergy = true;             // EMA Energy
input bool            channelBal = true;            // Channel Balance
input bool            autoTL = false;               // Auto Trend Lines

//--- Module - Signals - SL - TPS
input group           "Module - Signals - SL - TPS"
input int             numTP = 3;                    // Number of Take Profit Levels
input ENUM_TP_METHOD  PercentOrATR = TP_METHOD_ATR; // Calculation method for TakeProfit
input bool            levels = true;                // Show Entry Labels/SL/TP
input int             atrLen = 14;                  // ATR Length TP
input double          atrRisk = 1.0;                // Riesgo trade
input double          tpLen = 2.0;                  // TP [%]
input double          tpLenpre = 0.5;               // TP Initial Predictum [%]
input double          tpSL = 3.0;                   // SL [%]
input int             lvlDecimals = 3;              // Decimals
input bool            lvlLines = true;              // Show TP/SL lines?
input ENUM_LINE_STYLE linesStyle = STYLE_DOT;       // Line Style
input int             lvlLinesw = 1;                // TP/SL Line Thickness
input int             filllvlLines = 79;            // Fill TP/SL Line Alpha %
input bool            filllvlLineson = true;        // Show TP/SL Fill lines?
input int             MovingTarget = 2;             // Moving Target (BE)
input bool            showLabel = false;            // Showlabel Signal Generator

//--- Max Profit
input group           "Max Profit"
input int             leverage_maxpro = 1;          // Leverage x
input bool            levelsmaxpro = false;         // Show Labels Max Profit
input int             yposmaxpro = 1;               // Y Label Position Max Profit

//--- Supply/Demand
input group           "Supply/Demand Settings"
input int             swing_length = 10;            // Swing High/Low Length
input int             history_of_demand_to_keep = 20; // History To Keep
input double          box_width = 2.5;              // Supply/Demand Box Width
input group           "Supply/Demand Visuals"
input bool            show_zigzag = false;          // Show Zig Zag
input bool            show_price_action_labels = false; // Show Price Action Labels
input color           supply_color = C'0xED,0xED,0xED'; // Supply
input color           supply_outline_color = clrWhite; // Outline
input color           demand_color = clrAqua;       // Demand
input color           demand_outline_color = clrWhite; // Outline
input color           bos_label_color = clrWhite;   // BOS Label
input color           poi_label_color = clrWhite;   // POI Label
input color           swing_type_color = clrBlack;  // Price Action Label
input color           zigzag_color = clrBlack;      // Zig Zag

//--- Global variables, indicator buffers, handles etc. will be declared here
// Indicator Buffers
double Color_Buffer[];
double EMA_Buffer[];
double PacLo_Buffer[];
double PacHi_Buffer[];
double PacCe_Buffer[];
double Fill_Upper_Buffer[];
double Fill_Lower_Buffer[];

// Indicator Handles
int ema_handle;
int pac_lo_handle;
int pac_hi_handle;
int pac_ce_handle;
int psar_handle;
int sma_handles[9];
int sma_periods[9] = {8, 9, 10, 11, 12, 13, 14, 15, 15};
int kc_basis_handle;
int kc_atr_handle;
int supertrend_atr_handle;
int signal_atr_handle;
double kc_mults[4] = {10.5, 9.5, 8.0, 3.0};


// AI Signals Buffers
double Sma_Buffers[9][];
double Sma_Color_Buffers[9][];
double Psar_Buffer[];
// KC Buffers
double KC_EMA_Buffers[8][]; // k1..k8
double KC_Fill_Buffers[6][2][]; // 6 fills, 2 buffers each
// Supertrend Buffers/Arrays
double Supertrend_Buffer[];
int    Supertrend_Direction[];
// Pivot and LR Arrays
double PivotHigh_Buffer[];
double PivotLow_Buffer[];
double g_last_pivot_high;
double g_last_pivot_low;
// Signal Buffers for EA
double BullSignal_Buffer[];
double BearSignal_Buffer[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, Color_Buffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(1, EMA_Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, PacLo_Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, PacHi_Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, PacCe_Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, Fill_Upper_Buffer, INDICATOR_DATA);
   SetIndexBuffer(6, Fill_Lower_Buffer, INDICATOR_DATA);

   // AI Signals Buffers
   int buffer_offset = 7;
   for(int i = 0; i < 9; i++)
     {
      SetIndexBuffer(buffer_offset + i * 2, Sma_Buffers[i], INDICATOR_DATA);
      SetIndexBuffer(buffer_offset + i * 2 + 1, Sma_Color_Buffers[i], INDICATOR_COLOR_INDEX);
     }
   buffer_offset += 18;
   SetIndexBuffer(buffer_offset, Psar_Buffer, INDICATOR_DATA);
   buffer_offset++;

   SetIndexBuffer(buffer_offset, Supertrend_Buffer, INDICATOR_DATA);
   PlotIndexSetInteger(buffer_offset, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_WIDTH, 2);
   buffer_offset++;

   SetIndexBuffer(buffer_offset, PivotHigh_Buffer, INDICATOR_DATA);
   PlotIndexSetInteger(buffer_offset, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_COLOR, clrRed);
   buffer_offset++;

   SetIndexBuffer(buffer_offset, PivotLow_Buffer, INDICATOR_DATA);
   PlotIndexSetInteger(buffer_offset, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_COLOR, clrGreen);
   buffer_offset++;


   // KC EMA Buffers (k1-k8)
   for(int i=0; i<8; i++)
     {
      SetIndexBuffer(buffer_offset + i, KC_EMA_Buffers[i], INDICATOR_DATA);
     }
   buffer_offset += 8;

   // KC Fill Buffers
   for(int i=0; i<6; i++)
     {
      SetIndexBuffer(buffer_offset + i * 2,     KC_Fill_Buffers[i][0], INDICATOR_DATA);
      SetIndexBuffer(buffer_offset + i * 2 + 1, KC_Fill_Buffers[i][1], INDICATOR_DATA);
     }
   buffer_offset += 12;

   // EA Signal Buffers
   SetIndexBuffer(buffer_offset, BullSignal_Buffer, INDICATOR_DATA);
   SetIndexBuffer(buffer_offset + 1, BearSignal_Buffer, INDICATOR_DATA);


//--- Set plot labels
   PlotIndexSetString(0, PLOT_LABEL, "Bar Colors");
   PlotIndexSetString(1, PLOT_LABEL, "EMA");
   PlotIndexSetString(2, PLOT_LABEL, "Low Wave EMA");
   PlotIndexSetString(3, PLOT_LABEL, "High Wave EMA");
   PlotIndexSetString(4, PLOT_LABEL, "Centre Wave EMA");
   PlotIndexSetString(5, PLOT_LABEL, "Fill Channel");

   buffer_offset = 7;
   for(int i=0; i<9; i++)
     {
      PlotIndexSetString(buffer_offset+i, PLOT_LABEL, "SMA"+string(i+1));
      PlotIndexSetInteger(buffer_offset+i, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
      PlotIndexSetInteger(buffer_offset+i, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(buffer_offset+i, PLOT_LINE_WIDTH, 1);
      PlotIndexSetDouble(buffer_offset + i*2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
     }
   buffer_offset += 9;
   PlotIndexSetString(buffer_offset, PLOT_LABEL, "PSAR");
   PlotIndexSetInteger(buffer_offset, PLOT_DRAW_TYPE, DRAW_CIRCLES);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_WIDTH, 1);
   PlotIndexSetDouble(buffer_offset, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   buffer_offset++;

   // KC Plots
   for(int i=0; i<8; i++) // k1-k8 lines are invisible
     {
      PlotIndexSetInteger(buffer_offset + i, PLOT_DRAW_TYPE, DRAW_NONE);
     }
   buffer_offset += 8;

   // KC Fills
   for(int i=0; i<6; i++)
     {
      PlotIndexSetInteger(buffer_offset + i, PLOT_DRAW_TYPE, DRAW_FILLING);
      PlotIndexSetDouble(buffer_offset + i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
     }
   buffer_offset += 6;

   // EA Signal Plots
   PlotIndexSetString(buffer_offset, PLOT_LABEL, "Buy Signal");
   PlotIndexSetInteger(buffer_offset, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(buffer_offset, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_COLOR, clrBlue);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_WIDTH, 2);
   PlotIndexSetDouble(buffer_offset, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   buffer_offset++;

   PlotIndexSetString(buffer_offset, PLOT_LABEL, "Sell Signal");
   PlotIndexSetInteger(buffer_offset, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(buffer_offset, PLOT_ARROW, 234); // Down Arrow
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_COLOR, clrRed);
   PlotIndexSetInteger(buffer_offset, PLOT_LINE_WIDTH, 2);
   PlotIndexSetDouble(buffer_offset, PLOT_EMPTY_VALUE, EMPTY_VALUE);


//--- Set empty value for plots
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Set plot colors
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, ema_color);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, C'255,0,0');    // pacLo - Red
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, C'0,255,0');    // pacHi - Green
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, C'0,0,0');      // pacCe - Black
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, clrGray);      // Fill color for plot #6 (uses buffers 5 and 6)


//--- Initialize indicator handles
   ema_handle = iMA(_Symbol, _Period, len, 0, MODE_EMA, src);
   if(ema_handle == INVALID_HANDLE)
     {
      printf("Error creating EMA handle");
      return(INIT_FAILED);
     }

   pac_lo_handle = iMA(_Symbol, _Period, PACLen, 0, MODE_EMA, PRICE_LOW);
   if(pac_lo_handle == INVALID_HANDLE)
     {
      printf("Error creating PAC Low handle");
      return(INIT_FAILED);
     }

   pac_hi_handle = iMA(_Symbol, _Period, PACLen, 0, MODE_EMA, PRICE_HIGH);
   if(pac_hi_handle == INVALID_HANDLE)
     {
      printf("Error creating PAC High handle");
      return(INIT_FAILED);
     }

   pac_ce_handle = iMA(_Symbol, _Period, PACLen, 0, MODE_EMA, src2);
   if(pac_ce_handle == INVALID_HANDLE)
     {
      printf("Error creating PAC Center handle");
      return(INIT_FAILED);
     }

   // AI Signals Handles
   for(int i=0; i<9; i++)
     {
      sma_handles[i] = iMA(_Symbol, _Period, sma_periods[i], 0, MODE_SMA, PRICE_CLOSE);
      if(sma_handles[i] == INVALID_HANDLE)
        {
         printf("Error creating SMA handle %d", i+1);
         return(INIT_FAILED);
        }
     }
   psar_handle = iSAR(_Symbol, _Period, 0.02, 0.2);
   if(psar_handle == INVALID_HANDLE)
     {
      printf("Error creating PSAR handle");
      return(INIT_FAILED);
     }

   // KC Handles
   kc_basis_handle = iMA(_Symbol, _Period, 80, 0, MODE_SMA, PRICE_CLOSE);
   if(kc_basis_handle == INVALID_HANDLE)
     {
      printf("Error creating KC Basis handle");
      return(INIT_FAILED);
     }
   kc_atr_handle = iATR(_Symbol, _Period, 80);
   if(kc_atr_handle == INVALID_HANDLE)
     {
      printf("Error creating KC ATR handle");
      return(INIT_FAILED);
     }

   // Supertrend ATR Handle
   supertrend_atr_handle = iATR(_Symbol, _Period, 11);
   if(supertrend_atr_handle == INVALID_HANDLE)
     {
      printf("Error creating Supertrend ATR handle");
      return(INIT_FAILED);
     }

   // Signal ATR Handle
   signal_atr_handle = iATR(_Symbol, _Period, 30);
   if(signal_atr_handle == INVALID_HANDLE)
     {
      printf("Error creating Signal ATR handle");
      return(INIT_FAILED);
     }


//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- Calculate start position
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

//--- Copy indicator data
   if(CopyBuffer(ema_handle, 0, start, rates_total - start, EMA_Buffer) <= 0) return(0);
   if(CopyBuffer(pac_lo_handle, 0, start, rates_total - start, PacLo_Buffer) <= 0) return(0);
   if(CopyBuffer(pac_hi_handle, 0, start, rates_total - start, PacHi_Buffer) <= 0) return(0);
   if(CopyBuffer(pac_ce_handle, 0, start, rates_total - start, PacCe_Buffer) <= 0) return(0);

   // Copy AI Signals data
   for(int i=0; i<9; i++)
      if(CopyBuffer(sma_handles[i], 0, start, rates_total - start, Sma_Buffers[i]) <= 0) return(0);
   if(CopyBuffer(psar_handle, 0, start, rates_total - start, Psar_Buffer) <= 0) return(0);

   // Copy KC base data
   double kc_basis_data[], kc_atr_data[];
   if(CopyBuffer(kc_basis_handle, 0, 0, rates_total, kc_basis_data) <= 0) return(0);
   if(CopyBuffer(kc_atr_handle, 0, 0, rates_total, kc_atr_data) <= 0) return(0);

   // Copy Supertrend ATR data
   double st_atr_data[];
   if(CopyBuffer(supertrend_atr_handle, 0, 0, rates_total, st_atr_data) <= 0) return(0);

   // Copy Signal ATR data
   double signal_atr_data[];
   if(CopyBuffer(signal_atr_handle, 0, 0, rates_total, signal_atr_data) <= 0) return(0);

   // Calculate KC Bands and their EMAs
   double upper_kc_bands[4][], lower_kc_bands[4][];
   for(int i=0; i<4; i++)
     {
      ArrayResize(upper_kc_bands[i], rates_total);
      ArrayResize(lower_kc_bands[i], rates_total);
      for(int j=0; j<rates_total; j++)
        {
         upper_kc_bands[i][j] = kc_basis_data[j] + kc_atr_data[j] * kc_mults[i];
         lower_kc_bands[i][j] = kc_basis_data[j] - kc_atr_data[j] * kc_mults[i];
        }
      // Calculate EMA of the bands
      // k1..k4 are EMAs of upper bands
      iMAOnArray(upper_kc_bands[i], rates_total, 50, 0, MODE_EMA, KC_EMA_Buffers[i]);
      // k5..k8 are EMAs of lower bands
      iMAOnArray(lower_kc_bands[i], rates_total, 50, 0, MODE_EMA, KC_EMA_Buffers[i+4]);
     }


//--- Main calculation loop
   // Initialize global pivot values on first run
   if(prev_calculated == 0)
     {
      g_last_pivot_high = EMPTY_VALUE;
      g_last_pivot_low = EMPTY_VALUE;
      ArrayInitialize(Supertrend_Direction, 0);
     }

   for(int i = start; i < rates_total; i++)
     {
      // --- AI Signals Calculations ---
      CalculateSupertrend(i, close, st_atr_data);
      CalculatePivots(i, high, low, rates_total);

      double lr_slope_val, lr_intercept_val, lr_upDev, lr_dnDev;
      CalculateLinearRegression(i, close, high, low, 150, lr_slope_val, lr_intercept_val, lr_upDev, lr_dnDev);

      // --- Volume Profile Logic ---
      if(i == rates_total - 1) // Only run on the last bar
        {
         CalculateAndDrawVolumeProfile(i, rates_total, high, low, volume, time);
        }

      // --- Final Signal Logic and Object Plotting ---
      bool is_bull = (close[i-1] < Supertrend_Buffer[i-1] && close[i] > Supertrend_Buffer[i]) && (close[i] >= Sma_Buffers[8][i]);
      bool is_bear = (close[i-1] > Supertrend_Buffer[i-1] && close[i] < Supertrend_Buffer[i]) && (close[i] <= Sma_Buffers[8][i]);

      // Set EA Signal Buffers
      BullSignal_Buffer[i] = EMPTY_VALUE;
      BearSignal_Buffer[i] = EMPTY_VALUE;

      if(is_bull)
        {
         BullSignal_Buffer[i] = low[i];
         double y_pos = low[i] - signal_atr_data[i] * 1.6;
         string name = "buy_signal_"+(string)time[i];
         ObjectCreate(0, name, OBJ_LABEL, 0, time[i], y_pos);
         ObjectSetString(0, name, OBJPROP_TEXT, "▲");
         ObjectSetInteger(0, name, OBJPROP_COLOR, C'16,43,248');
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
        }
      if(is_bear)
        {
         BearSignal_Buffer[i] = high[i];
         double y_pos = high[i] + signal_atr_data[i] * 1.6;
         string name = "sell_signal_"+(string)time[i];
         ObjectCreate(0, name, OBJ_LABEL, 0, time[i], y_pos);
         ObjectSetString(0, name, OBJPROP_TEXT, "▼");
         ObjectSetInteger(0, name, OBJPROP_COLOR, C'180,6,13');
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
        }

      if(breaks)
        {
         if(close[i-1] < PivotHigh_Buffer[i-1] && close[i] > PivotHigh_Buffer[i])
           {
            double y_pos = low[i] - signal_atr_data[i];
            string name = "break_up_"+(string)time[i];
            ObjectCreate(0, name, OBJ_LABEL, 0, time[i], y_pos);
            ObjectSetString(0, name, OBJPROP_TEXT, "B");
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
           }
         if(close[i-1] > PivotLow_Buffer[i-1] && close[i] < PivotLow_Buffer[i])
           {
            double y_pos = high[i] + signal_atr_data[i];
            string name = "break_dn_"+(string)time[i];
            ObjectCreate(0, name, OBJ_LABEL, 0, time[i], y_pos);
            ObjectSetString(0, name, OBJPROP_TEXT, "B");
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
           }
        }

      if(autoTL && i == rates_total -1) // Only draw for the most recent calculation
        {
         datetime x1 = time[i-150+1];
         double y1_base = lr_intercept_val + lr_slope_val * (150 - 1);
         datetime x2 = time[i];
         double y2_base = lr_intercept_val;

         // Upper line
         ObjectCreate(0, "upperTL", OBJ_TREND, 0, x1, y1_base + lr_upDev, x2, y2_base + lr_upDev);
         ObjectSetInteger(0, "upperTL", OBJPROP_COLOR, clrRed);
         // Middle line
         ObjectCreate(0, "middleTL", OBJ_TREND, 0, x1, y1_base, x2, y2_base);
         ObjectSetInteger(0, "middleTL", OBJPROP_COLOR, clrWhite);
         // Lower line
         ObjectCreate(0, "lowerTL", OBJ_TREND, 0, x1, y1_base - lr_dnDev, x2, y2_base - lr_dnDev);
         ObjectSetInteger(0, "lowerTL", OBJPROP_COLOR, clrGreen);
        }


      // --- Bar Coloring Logic ---
      if(ShowBarColor)
        {
         // PineScript logic: Green if above channel, Red if below, White if inside.
         double pacHi = PacHi_Buffer[i];
         double pacLo = PacLo_Buffer[i];
         int color_index = 2; // Default to White (inside channel)

         if(pacHi != EMPTY_VALUE && pacLo != EMPTY_VALUE)
           {
            if(close[i] >= pacHi) color_index = 0;      // Green (above channel)
            else if(close[i] <= pacLo) color_index = 1; // Red (below channel)
           }

         Color_Buffer[i] = color_index;
        }
      else
        {
         Color_Buffer[i] = EMPTY_VALUE;
        }

      // --- EMA Wave (PAC) Logic ---
      if(!ShowPAC)
        {
         PacLo_Buffer[i] = EMPTY_VALUE;
         PacHi_Buffer[i] = EMPTY_VALUE;
         PacCe_Buffer[i] = EMPTY_VALUE;
         Fill_Upper_Buffer[i] = EMPTY_VALUE;
         Fill_Lower_Buffer[i] = EMPTY_VALUE;
        }
      else
        {
         Fill_Upper_Buffer[i] = PacHi_Buffer[i];
         Fill_Lower_Buffer[i] = PacLo_Buffer[i];
        }

      // --- AI Signals Logic ---

      // EMA Energy
      if(emaEnergy)
        {
         for(int j=0; j<9; j++)
           {
            Sma_Color_Buffers[j][i] = (close[i] >= Sma_Buffers[j][i]) ? 0 : 1; // 0=Green, 1=Red
           }
        }
      else
        {
         for(int j=0; j<9; j++)
           {
            Sma_Buffers[j][i] = EMPTY_VALUE;
           }
        }

      // PSAR
      if(!usePsar)
        {
         Psar_Buffer[i] = EMPTY_VALUE;
        }

      // KC Fills
      if(channelBal)
        {
         // Fill k1-k2, k2-k3, k3-k4
         KC_Fill_Buffers[0][0][i] = KC_EMA_Buffers[0][i]; KC_Fill_Buffers[0][1][i] = KC_EMA_Buffers[1][i];
         KC_Fill_Buffers[1][0][i] = KC_EMA_Buffers[1][i]; KC_Fill_Buffers[1][1][i] = KC_EMA_Buffers[2][i];
         KC_Fill_Buffers[2][0][i] = KC_EMA_Buffers[2][i]; KC_Fill_Buffers[2][1][i] = KC_EMA_Buffers[3][i];
         // Fill k5-k6, k6-k7, k7-k8
         KC_Fill_Buffers[3][0][i] = KC_EMA_Buffers[4][i]; KC_Fill_Buffers[3][1][i] = KC_EMA_Buffers[5][i];
         KC_Fill_Buffers[4][0][i] = KC_EMA_Buffers[5][i]; KC_Fill_Buffers[4][1][i] = KC_EMA_Buffers[6][i];
         KC_Fill_Buffers[5][0][i] = KC_EMA_Buffers[6][i]; KC_Fill_Buffers[5][1][i] = KC_EMA_Buffers[7][i];
        }
      else
        {
         for(int j=0; j<6; j++)
           {
            KC_Fill_Buffers[j][0][i] = EMPTY_VALUE;
            KC_Fill_Buffers[j][1][i] = EMPTY_VALUE;
           }
        }

     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- remove all graphical objects & release handles
   IndicatorRelease(ema_handle);
   IndicatorRelease(pac_lo_handle);
   IndicatorRelease(pac_hi_handle);
   IndicatorRelease(pac_ce_handle);
   IndicatorRelease(psar_handle);
   for(int i=0; i<9; i++) IndicatorRelease(sma_handles[i]);
   IndicatorRelease(kc_basis_handle);
   IndicatorRelease(kc_atr_handle);
   IndicatorRelease(supertrend_atr_handle);
   IndicatorRelease(signal_atr_handle);

   // Delete objects on deinit
   ObjectsDeleteAll(0, "buy_signal_");
   ObjectsDeleteAll(0, "sell_signal_");
   ObjectsDeleteAll(0, "break_up_");
   ObjectsDeleteAll(0, "break_dn_");
   ObjectDelete(0, "upperTL");
   ObjectDelete(0, "middleTL");
   ObjectDelete(0, "lowerTL");
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                      HELPER FUNCTIONS                            |
//+------------------------------------------------------------------+
void CalculateSupertrend(int i, const double &close[], const double &atr[])
{
   double factor = (sensitivity == SENSITIVITY_LOW) ? 5.0 : (sensitivity == SENSITIVITY_MEDIUM) ? 2.5 : 2.0;

   double upper_band = close[i] + factor * atr[i];
   double lower_band = close[i] - factor * atr[i];

   double prev_lower_band = (i > 0) ? Supertrend_Buffer[i-1] : lower_band; // Simplified logic for prev bands
   double prev_upper_band = (i > 0) ? Supertrend_Buffer[i-1] : upper_band;

   if(i > 0)
   {
      if(Supertrend_Direction[i-1] == 1) // Previous was uptrend
         prev_lower_band = MathMax(lower_band, (i > 0) ? Supertrend_Buffer[i-1] : lower_band);
      else // Previous was downtrend
         prev_upper_band = MathMin(upper_band, (i > 0) ? Supertrend_Buffer[i-1] : upper_band);
   }


   int direction = Supertrend_Direction[i-1];
   if(i == 0) direction = 1;
   else if(Supertrend_Buffer[i-1] == prev_upper_band)
      direction = (close[i] > prev_upper_band) ? 1 : -1;
   else
      direction = (close[i] < prev_lower_band) ? -1 : 1;

   Supertrend_Buffer[i] = (direction == 1) ? prev_lower_band : prev_upper_band;
   Supertrend_Direction[i] = direction;
}

void CalculatePivots(int i, const double &high[], const double &low[], int rates_total)
{
   int barsL = 10, barsR = 10;

   // Check for pivot confirmation at 'i - barsR - 1'
   int pivot_check_bar = i - barsR -1;
   if(pivot_check_bar < 0)
     {
      PivotHigh_Buffer[i] = g_last_pivot_high;
      PivotLow_Buffer[i] = g_last_pivot_low;
      return;
     }

   // --- Pivot High ---
   double new_pivot_high = GetPivotHigh(high, pivot_check_bar, barsL, barsR, rates_total);
   if(new_pivot_high != EMPTY_VALUE)
   {
      g_last_pivot_high = new_pivot_high;
   }
   PivotHigh_Buffer[i] = g_last_pivot_high;

   // --- Pivot Low ---
   double new_pivot_low = GetPivotLow(low, pivot_check_bar, barsL, barsR, rates_total);
   if(new_pivot_low != EMPTY_VALUE)
   {
      g_last_pivot_low = new_pivot_low;
   }
   PivotLow_Buffer[i] = g_last_pivot_low;
}


double GetPivotHigh(const double &price[], int bar, int left, int right, int rates_total)
{
    if (bar - left < 0 || bar + right >= rates_total) return EMPTY_VALUE;
    double pivot_val = price[bar];
    for (int j = 1; j <= left; j++) {
        if (price[bar - j] > pivot_val) return EMPTY_VALUE;
    }
    for (int j = 1; j <= right; j++) {
        if (price[bar + j] >= pivot_val) return EMPTY_VALUE;
    }
    return pivot_val;
}

double GetPivotLow(const double &price[], int bar, int left, int right, int rates_total)
{
    if (bar - left < 0 || bar + right >= rates_total) return EMPTY_VALUE;
    double pivot_val = price[bar];
    for (int j = 1; j <= left; j++) {
        if (price[bar - j] < pivot_val) return EMPTY_VALUE;
    }
    for (int j = 1; j <= right; j++) {
        if (price[bar + j] <= pivot_val) return EMPTY_VALUE;
    }
    return pivot_val;
}

//+------------------------------------------------------------------+
//| Volume Profile Helper Functions                                  |
//+------------------------------------------------------------------+
double GetVol(double y11, double y12, double y21, double y22, double height, double vol)
{
    if(height <= 0) return 0;
    double min_of_maxes = MathMin(MathMax(y11, y12), MathMax(y21, y22));
    double max_of_mins = MathMax(MathMin(y11, y12), MathMin(y21, y22));
    double intersection = MathMax(min_of_maxes - max_of_mins, 0);
    return intersection * vol / height;
}

void CalculateAndDrawVolumeProfile(int current_bar, int rates_total, const double &high[], const double &low[], const long &volume[], const datetime &time[])
{
    // --- Clear previous VP objects ---
    ObjectsDeleteAll(0, "VP_");

    // --- Calculations ---
    int highest_bar_idx = iHighest(NULL, 0, MODE_HIGH, bbars, current_bar - bbars + 1);
    int lowest_bar_idx = iLowest(NULL, 0, MODE_LOW, bbars, current_bar - bbars + 1);
    double top = high[highest_bar_idx];
    double bot = low[lowest_bar_idx];

    if(top == bot) return; // Avoid division by zero

    double dist = (top - bot) / 500.0;
    double step = (top - bot) / cnum;

    double levels5[];
    ArrayResize(levels5, cnum + 1);
    for(int x = 0; x <= cnum; x++)
    {
        levels5[x] = bot + step * x;
    }

    double volumes[];
    ArrayResize(volumes, cnum * 2);
    ArrayInitialize(volumes, 0.0);

    for(int bars = 0; bars < bbars; bars++)
    {
        int bar_idx = current_bar - bars;
        if(bar_idx < 0) break;

        double body_top = MathMax(close[bar_idx], open[bar_idx]);
        double body_bot = MathMin(close[bar_idx], open[bar_idx]);
        bool itsgreen = close[bar_idx] >= open[bar_idx];

        double topwick = high[bar_idx] - body_top;
        double bottomwick = body_bot - low[bar_idx];
        double body = body_top - body_bot;

        double total_dist = 2 * topwick + 2 * bottomwick + body;
        if(total_dist <= 0) continue;

        double bodyvol = body * volume[bar_idx] / total_dist;
        double topwickvol = 2 * topwick * volume[bar_idx] / total_dist;
        double bottomwickvol = 2 * bottomwick * volume[bar_idx] / total_dist;

        for(int x = 0; x < cnum; x++)
        {
            double up_vol = (itsgreen ? GetVol(levels5[x], levels5[x+1], body_bot, body_top, body, bodyvol) : 0) +
                             GetVol(levels5[x], levels5[x+1], body_top, high[bar_idx], topwick, topwickvol) / 2.0 +
                             GetVol(levels5[x], levels5[x+1], low[bar_idx], body_bot, bottomwick, bottomwickvol) / 2.0;

            double down_vol = (!itsgreen ? GetVol(levels5[x], levels5[x+1], body_bot, body_top, body, bodyvol) : 0) +
                               GetVol(levels5[x], levels5[x+1], body_top, high[bar_idx], topwick, topwickvol) / 2.0 +
                               GetVol(levels5[x], levels5[x+1], low[bar_idx], body_bot, bottomwick, bottomwickvol) / 2.0;

            volumes[x] += up_vol;
            volumes[x + cnum] += down_vol;
        }
    }

    double totalvols[];
    ArrayResize(totalvols, cnum);
    double totalmax = 0;
    for(int x=0; x<cnum; x++)
    {
        totalvols[x] = volumes[x] + volumes[x + cnum];
        totalmax += totalvols[x];
    }

    if(totalmax <= 0) return;

    int poc = (int)ArrayMaximum(totalvols, 0, cnum);
    double maxvol = totalvols[poc];

    double va_target = totalmax * (percent / 100.0);
    double va_total = totalvols[poc];
    int va_up = poc;
    int va_down = poc;

    for(int x=0; x<cnum; x++)
    {
        if(va_total >= va_target) break;

        double uppervol = (va_up < cnum - 1) ? totalvols[va_up + 1] : 0;
        double lowervol = (va_down > 0) ? totalvols[va_down - 1] : 0;

        if(uppervol == 0 && lowervol == 0) break;

        if(uppervol >= lowervol)
        {
            va_total += uppervol;
            va_up++;
        }
        else
        {
            va_total += lowervol;
            va_down--;
        }
    }

    for(int x=0; x<cnum*2; x++)
    {
       if(maxvol > 0)
         volumes[x] = volumes[x] * bbars / (3 * maxvol);
       else
         volumes[x] = 0;
    }

    // --- Drawing ---
    datetime time1 = time[current_bar - bbars + 1];

    for(int x=0; x<cnum; x++)
    {
        double vol_up_width = MathRound(volumes[x]);
        double vol_down_width = MathRound(volumes[x + cnum]);

        datetime time2_up = time1 + (int)vol_up_width * _PeriodSeconds;
        datetime time2_down = time2_up + (int)vol_down_width * _PeriodSeconds;

        color up_box_color = (x >= va_down && x <= va_up) ? vup_color : up_color;
        color down_box_color = (x >= va_down && x <= va_up) ? vdown_color : down_color;

        // Up volume box
        string up_name = "VP_up_" + (string)x;
        ObjectCreate(0, up_name, OBJ_RECTANGLE_LABEL, 0, time1, levels5[x+1] - dist, time2_up, levels5[x] + dist);
        ObjectSetInteger(0, up_name, OBJPROP_COLOR, up_box_color);
        ObjectSetInteger(0, up_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, up_name, OBJPROP_BORDER_TYPE, BORDER_NONE);

        // Down volume box
        string down_name = "VP_down_" + (string)x;
        ObjectCreate(0, down_name, OBJ_RECTANGLE_LABEL, 0, time2_up, levels5[x+1] - dist, time2_down, levels5[x] + dist);
        ObjectSetInteger(0, down_name, OBJPROP_COLOR, down_box_color);
        ObjectSetInteger(0, down_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, down_name, OBJPROP_BORDER_TYPE, BORDER_NONE);
    }

    // POC Line
    double poc_level = (levels5[poc] + levels5[poc+1]) / 2.0;
    datetime poc_time_start = time[current_bar - bbars + 1];
    datetime poc_time_end = time[current_bar + 1]; // Extend to the right
    ObjectCreate(0, "VP_poc_line", OBJ_TREND, 0, poc_time_start, poc_level, poc_time_end, poc_level);
    ObjectSetInteger(0, "VP_poc_line", OBJPROP_COLOR, poc_color);
    ObjectSetInteger(0, "VP_poc_line", OBJPROP_WIDTH, poc_width);
    ObjectSetInteger(0, "VP_poc_line", OBJPROP_RAY_RIGHT, true);

    if(show_poc)
    {
        string poc_text = "POC: " + DoubleToString(poc_level, _Digits);
        ObjectCreate(0, "VP_poc_label", OBJ_TEXT, 0, time[current_bar] + 15 * _PeriodSeconds, poc_level);
        ObjectSetString(0, "VP_poc_label", OBJPROP_TEXT, poc_text);
        ObjectSetInteger(0, "VP_poc_label", OBJPROP_COLOR, poc_color);
    }
}


void CalculateLinearRegression(int i, const double &src[], const double &high[], const double &low[], int period, double &slope, double &intercept, double &upDev, double &dnDev)
{
   if(i < period - 1) return;

   slope = 0; intercept = 0; upDev = 0; dnDev = 0;

   double sum_x = 0, sum_y = 0, sum_x2 = 0, sum_xy = 0;
   for(int j = 0; j < period; j++)
     {
      double val = src[i - j];
      double per = j + 1;
      sum_x += per;
      sum_y += val;
      sum_x2 += per * per;
      sum_xy += val * per;
     }

   double denominator = (period * sum_x2 - sum_x * sum_x);
   if(denominator == 0) return;

   slope = (period * sum_xy - sum_x * sum_y) / denominator;
   double avg = sum_y / period;
   intercept = avg - slope * sum_x / period + slope;

   upDev = 0.0;
   dnDev = 0.0;
   double lr_val = intercept;
   for(int j = 0; j < period; j++)
     {
      double price_up = high[i - j] - lr_val;
      if(price_up > upDev) upDev = price_up;

      double price_dn = lr_val - low[i - j];
      if(price_dn > dnDev) dnDev = price_dn;

      lr_val += slope;
     }
}

//+------------------------------------------------------------------+
//| Dashboard Helper Function                                        |
//+------------------------------------------------------------------+
void CalculateAndDrawDashboard(int i, int rates_total, const double &high[], const double &low[], const double &close[], const datetime &time[], const long &volume[])
{
   if(!dashOn)
     {
      ObjectDelete(0, "DashboardLabel");
      return;
     }

   // --- Calculations ---
   // Volatility (simplified)
   double atr_buffer[1];
   double percentVol = 0;
   if(CopyBuffer(dash_atr_handle, 0, 0, 1, atr_buffer) > 0)
     {
      percentVol = atr_buffer[0] / close[i] * 100; // Simplified volatility metric
     }

   // Volume
   long volumeDash = volume[i];

   // RSI
   double rsi_buffer[1];
   double rsiDash = 0;
   if(CopyBuffer(dash_rsi_handle, 0, 0, 1, rsi_buffer) > 0)
     {
      rsiDash = rsi_buffer[0];
     }

   // Sentiment
   double ema_buffer[3];
   string totalSentTxt = "Flat";
   if(CopyBuffer(dash_ema_handle, 0, 0, 3, ema_buffer) > 0)
     {
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
         trends[t] = (sma_buffer[0] > sma_buffer[1]) ? "🟢" : "🔴";
        }
      else
        {
         trends[t] = "⚪"; // Data not ready
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
   text += "     " + timeframe_names[0] + " | " + trends[0] + "         " + timeframe_names[5] + " | " + trends[5] + "\n";
   text += "     " + timeframe_names[1] + " | " + trends[1] + "         " + timeframe_names[6] + " | " + trends[6] + "\n";
   text += "        " + timeframe_names[2] + " | " + trends[2] + "         " + timeframe_names[7] + " | " + trends[7] + "\n";
   text += "        " + timeframe_names[3] + " | " + trends[3] + "       " + timeframe_names[8] + " |     " + trends[8] + "\n";
   text += "        " + timeframe_names[4] + " | " + trends[4] + "                " + timeframe_names[9] + " | " + trends[9] + "\n";
   text += "━━━━━━━━━━━━━━━━━\n";
   text += "                     🔱CRIPTOM4N 🔱";

   string name = "DashboardLabel";
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_COLOR, dashTextColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, dashColor);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (int)dashDist);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 30);
      ObjectSetString(0, name, OBJPROP_FONT, "Courier New");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}
