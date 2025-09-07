//+------------------------------------------------------------------+
//|                                                       MegaAI.mq5 |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"
#property version   "1.00"
#property expert_version "1.00"
#property description "MegaAI Expert Advisor - Refactored from Pine Script"

//--- include module files
#include <Trade\Trade.mqh>
#include "VolumeProfile.mqh"
#include "Dashboard.mqh"
#include "EMATrend.mqh"
#include "EMAWave.mqh"
#include "AISignals.mqh"
#include "TPSLManager.mqh"
#include "MaxProfit.mqh"
#include "SupplyDemand.mqh"
#include "ZigZag.mqh"

//--- input parameters
//==================== TRADING ===========================
input double LotSize = 0.01; // Lot Size

//==================== VOLUME PROFILE ====================
input int    VP_NumberOfBars            = 150;      // Number of Bars
input int    VP_RowSize                 = 24;       // Row Size
input double VP_ValueAreaPercent        = 70.0;     // Value Area Volume %
input color  VP_POC_Color               = clrWhite; // POC Color
input int    VP_POC_Width               = 2;        // POC Width
input color  VP_ValueAreaUp             = clrBlue;  // Value Area Up
input color  VP_ValueAreaDown           = clrOrange;// Value Area Down
input color  VP_UpVolumeColor           = clrBlue;  // UP Volume
input color  VP_DownVolumeColor         = clrOrange;// Down Volume
input bool   VP_ShowPOCLabel            = false;    // Show POC Label

//==================== DASHBOARD =========================
input bool   Dash_On                    = true;                 // Dashboard On / Off
input int    Dash_Distance              = 93;                   // Dashboard Distance (X offset)
input color  Dash_Background            = clrBlack;             // Dashboard Color
input color  Dash_TextColor             = C'0,200,255';         // Text Color (cyan)

//==================== EMA / TREND =======================
input ENUM_APPLIED_PRICE EMA_Source     = PRICE_CLOSE; // EMA source
input int    EMA200_Period              = 200;         // EMA 200
input color  EMA_Color                  = clrYellow;   // EMA color

//==================== EMA WAVE & GRaB ===================
input bool   Show_EMA_Wave              = false;      // Show EMA Wave
input bool   Show_Grab_Candles          = true;       // Show Coloured GRaB Candles
input int    EMA_Wave_Length            = 34;         // EMA Wave Length
input ENUM_APPLIED_PRICE EMA_Wave_Center_Source = PRICE_CLOSE; // Wave centre EMA source

//==================== AI SIGNALS TOGGLES ================
enum ENUM_SENSITIVITY {SENSITIVITY_LOW, SENSITIVITY_MEDIUM, SENSITIVITY_HIGH};
input ENUM_SENSITIVITY Sensitivity = SENSITIVITY_LOW; // Sensitivity
input bool   Opt_SupportResistance      = true;   // Support & Resistance
input bool   Opt_Breaks                 = false;  // Breaks
input bool   Opt_PSAR                   = false;  // PSAR
input bool   Opt_EMA_Energy             = true;   // EMA Energy
input bool   Opt_ChannelBalance         = true;   // Channel Balance
input bool   Opt_AutoTrendLines         = false;  // Auto Trend Lines

//==================== MODULE - SIGNALS (TP/SL) ==========
enum TPMethod { TPM_ATR, TPM_PERCENTAGE, TPM_PREDICTUM };
input int       TP_NumberLevels         = 5;                 // Number of Take Profit Levels
input TPMethod  TP_CalcMethod           = TPM_ATR;           // Calculation method for TP
input bool      Levels_ShowLabels       = true;              // Show Entry Labels/SL/TP
input int       ATR_Length_TP           = 14;                // ATR Length TP
input double    Risk_Trade              = 1.0;               // Risk multiplier
input double    TP_Percent              = 2.0;               // TP [%]
input double    TP_Initial_Predictum    = 0.5;               // TP Initial Predictum [%]
input double    SL_Percent              = 3.0;               // SL [%]
input int       Price_Decimals          = 3;                 // Decimals

enum LineStyle { LS_SOLID, LS_DASHED, LS_DOTTED };
input bool      Show_TPSL_Lines         = true;              // Show TP/SL lines?
input LineStyle TPSL_LineStyle          = LS_DOTTED;         // Line style
input int       TPSL_Distance           = 3;                 // Distance
input int       TPSL_LineThickness      = 1;                 // Line thickness
input int       TPSL_FillAlphaPercent   = 60;                // Fill alpha %
input bool      TPSL_ShowFillLines      = true;              // Show fill?
input int       MovingTarget_BE         = 2;                 // Moving Target (BE)
input bool      ShowLabel_SignalGen     = false;             // Show Signal Generator label

//==================== MAX PROFIT ========================
input int    MaxProfit_LeverageX        = 1;     // Leverage x
input bool   MaxProfit_ShowLabels       = false; // Show Labels Max Profit
input int    MaxProfit_YLabelPos        = 1;     // Y Label Position

//==================== SUPPLY/DEMAND & SETTINGS ==========
input int    SD_SwingLen                = 10;    // Swing High/Low Length
input int    SD_HistoryToKeep           = 20;    // History To Keep
input double SD_BoxWidth                = 2.5;   // Supply/Demand Box Width

//==================== VISUAL SETTINGS ===================
input bool   VS_ShowZigZag              = false; // Show Zig Zag
input bool   VS_ShowPriceActionLabels   = false; // Show Price Action Labels
input color  VS_SupplyColor             = clrSilver; // Supply
input color  VS_SupplyOutline           = clrWhite;  // Supply Outline
input color  VS_DemandColor             = clrAqua;   // Demand
input color  VS_DemandOutline           = clrWhite;  // Demand Outline
input color  VS_BOSLabelColor           = clrWhite;  // BOS Label
input color  VS_POILabelColor           = clrWhite;  // POI Label
input color  VS_PriceActionLabelColor   = clrBlack;  // Price Action Label
input color  VS_ZigZagColor             = clrBlack;  // Zig Zag

//==================== MISC ==============================
input bool   ShowInputsInStatusLine     = true;  // Inputs in status line

// --- Global variables
CTrade         trade;
CVolumeProfile g_volume_profile;
CDashboard     g_dashboard;
CEMATrend      g_ema_trend;
CEMAWave       g_ema_wave;
CAISignals     g_ai_signals;
CTPSLManager   g_tpsl_manager;
CMaxProfit     g_max_profit;
CSupplyDemand  g_supply_demand;
CZigZag        g_zigzag;
datetime g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize Volume Profile
   g_volume_profile.Init(ChartID(), VP_NumberOfBars, VP_RowSize, VP_ValueAreaPercent, VP_POC_Color, VP_POC_Width, VP_ValueAreaUp, VP_ValueAreaDown, VP_UpVolumeColor, VP_DownVolumeColor, VP_ShowPOCLabel);
//--- Initialize Dashboard
   g_dashboard.Init(ChartID(), Dash_On, Dash_Distance, Dash_Background, Dash_TextColor);
//--- Initialize EMA Trend
   g_ema_trend.Init(ChartID(), EMA_Source, EMA200_Period, EMA_Color);
//--- Initialize EMA Wave
   g_ema_wave.Init(ChartID(), Show_EMA_Wave, Show_Grab_Candles, EMA_Wave_Length, EMA_Wave_Center_Source);
//--- Initialize AI Signals
   string sensitivity_str = EnumToString(Sensitivity);
   StringSubstr(sensitivity_str, 12); // Remove "SENSITIVITY_"
   g_ai_signals.Init(ChartID(), sensitivity_str, Opt_SupportResistance, Opt_Breaks, Opt_PSAR, Opt_EMA_Energy, Opt_ChannelBalance, Opt_AutoTrendLines);
//--- Initialize TP/SL Manager
   g_tpsl_manager.Init(ChartID(), TP_NumberLevels, TP_CalcMethod, Levels_ShowLabels, ATR_Length_TP, Risk_Trade, TP_Percent, TP_Initial_Predictum, SL_Percent, Price_Decimals, Show_TPSL_Lines, TPSL_LineStyle, TPSL_Distance, TPSL_LineThickness);
//--- Initialize Max Profit
   g_max_profit.Init(ChartID(), MaxProfit_LeverageX, MaxProfit_ShowLabels, MaxProfit_YLabelPos);
//--- Initialize Supply/Demand
   g_supply_demand.Init(ChartID(), SD_SwingLen, SD_HistoryToKeep, SD_BoxWidth, VS_SupplyColor, VS_SupplyOutline, VS_DemandColor, VS_DemandOutline, VS_BOSLabelColor, VS_POILabelColor);
//--- Initialize ZigZag
   g_zigzag.Init(ChartID(), VS_ShowZigZag, VS_ZigZagColor, SD_SwingLen);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Deinitialize Volume Profile
   g_volume_profile.Deinit();
//--- Deinitialize Dashboard
   g_dashboard.Deinit();
//--- Deinitialize EMA Trend
   g_ema_trend.Deinit();
//--- Deinitialize EMA Wave
   g_ema_wave.Deinit();
//--- Deinitialize AI Signals
   g_ai_signals.Deinit();
//--- Deinitialize TP/SL Manager
   g_tpsl_manager.Deinit();
//--- Deinitialize Max Profit
   g_max_profit.Deinit();
//--- Deinitialize Supply/Demand
   g_supply_demand.Deinit();
//--- Deinitialize ZigZag
   g_zigzag.Deinit();
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Check for new bar
   MqlRates rates[1];
   if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1)
      return;

   if(rates[0].time != g_last_bar_time)
     {
      g_last_bar_time = rates[0].time;

      //--- Calculations
      g_volume_profile.Calculate();
      g_dashboard.Calculate();
      g_ema_wave.CalculateAndDraw(); // This one draws on its own schedule
      g_ai_signals.Calculate();
      g_tpsl_manager.Calculate(g_ai_signals.IsBullSignal(), g_ai_signals.IsBearSignal());
      g_max_profit.Calculate(g_ai_signals.IsBullSignal(), g_ai_signals.IsBearSignal());
      g_supply_demand.CalculateAndDraw();
      g_zigzag.CalculateAndDraw();

      //--- Drawing
      g_volume_profile.Draw();
      g_dashboard.Draw();
      g_ai_signals.Draw();
      g_tpsl_manager.Draw();
      g_max_profit.Draw();

      //--- Trading Logic
      if(PositionsTotal() == 0)
      {
         if(g_ai_signals.IsBullSignal())
         {
            trade.Buy(LotSize, NULL, 0, g_tpsl_manager.GetSL(), g_tpsl_manager.GetTP(0), "MegaAI Buy");
         }
         else if(g_ai_signals.IsBearSignal())
         {
            trade.Sell(LotSize, NULL, 0, g_tpsl_manager.GetSL(), g_tpsl_manager.GetTP(0), "MegaAI Sell");
         }
      }
     }

     // Breakeven logic can be here, as it needs to run on every tick
}
//+------------------------------------------------------------------+
