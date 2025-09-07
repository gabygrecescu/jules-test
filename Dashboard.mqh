//+------------------------------------------------------------------+
//|                                                  Dashboard.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Dashboard module
class CDashboard
{
private:
    //--- Input parameters
    bool   m_dash_on;
    int    m_dash_dist;
    color  m_dash_color;
    color  m_dash_text_color;

    //--- Indicator handles
    int    m_atr_handle;
    int    m_stdev_handle;
    int    m_sma_atr_handle;
    int    m_rsi_handle;
    int    m_ema_sent_handle;

    // Trend Panel SMA handles
    int    m_sma_h_1M;
    int    m_sma_h_5M;
    int    m_sma_h_15M;
    int    m_sma_h_30M;
    int    m_sma_h_1H;
    int    m_sma_h_2H;
    int    m_sma_h_4H;
    int    m_sma_h_D1;
    int    m_sma_h_W1;
    int    m_sma_h_MN1;

    //--- Calculated data
    double m_percent_vol;
    double m_volume_dash;
    double m_rsi_dash;
    string m_total_sent_txt;

    //--- Object names
    string m_label_name;

    //--- Chart ID
    long m_chart_id;

public:
    void CDashboard();
    ~CDashboard();
    void Init(long chart_id, bool dash_on, int dash_dist, color dash_color, color text_color);
    void Calculate();
    void Draw();
    void Deinit();

private:
    string GetTrend(int handle);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CDashboard::CDashboard()
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CDashboard::~CDashboard()
{
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
void CDashboard::Init(long chart_id, bool dash_on, int dash_dist, color dash_color, color text_color)
{
    m_chart_id = chart_id;
    m_dash_on = dash_on;
    m_dash_dist = dash_dist;
    m_dash_color = dash_color;
    m_dash_text_color = text_color;

    m_label_name = "Dashboard_Label_" + (string)m_chart_id;

    if(m_dash_on)
    {
        // Volatility indicators
        m_atr_handle = iATR(_Symbol, _Period, 14);
        m_stdev_handle = iStDevOnArray(NULL, 0, 20, 0, MODE_SMA, m_atr_handle, 0);
        m_sma_atr_handle = iSMAOnArray(NULL, 0, 20, 0, m_atr_handle, 0);

        // RSI
        m_rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);

        // Sentiment
        m_ema_sent_handle = iEMA(_Symbol, _Period, 9, 0, PRICE_CLOSE);

        // Trend Panel SMAs
        m_sma_h_1M = iSMA(_Symbol, PERIOD_M1, 50, 0, PRICE_CLOSE);
        m_sma_h_5M = iSMA(_Symbol, PERIOD_M5, 50, 0, PRICE_CLOSE);
        m_sma_h_15M = iSMA(_Symbol, PERIOD_M15, 50, 0, PRICE_CLOSE);
        m_sma_h_30M = iSMA(_Symbol, PERIOD_M30, 50, 0, PRICE_CLOSE);
        m_sma_h_1H = iSMA(_Symbol, PERIOD_H1, 50, 0, PRICE_CLOSE);
        m_sma_h_2H = iSMA(_Symbol, PERIOD_H2, 50, 0, PRICE_CLOSE);
        m_sma_h_4H = iSMA(_Symbol, PERIOD_H4, 50, 0, PRICE_CLOSE);
        m_sma_h_D1 = iSMA(_Symbol, PERIOD_D1, 50, 0, PRICE_CLOSE);
        m_sma_h_W1 = iSMA(_Symbol, PERIOD_W1, 50, 0, PRICE_CLOSE);
        m_sma_h_MN1 = iSMA(_Symbol, PERIOD_MN1, 50, 0, PRICE_CLOSE);
    }
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void CDashboard::Deinit()
{
    if(m_dash_on)
    {
        IndicatorRelease(m_atr_handle);
        IndicatorRelease(m_stdev_handle);
        IndicatorRelease(m_sma_atr_handle);
        IndicatorRelease(m_rsi_handle);
        IndicatorRelease(m_ema_sent_handle);
        IndicatorRelease(m_sma_h_1M);
        IndicatorRelease(m_sma_h_5M);
        IndicatorRelease(m_sma_h_15M);
        IndicatorRelease(m_sma_h_30M);
        IndicatorRelease(m_sma_h_1H);
        IndicatorRelease(m_sma_h_2H);
        IndicatorRelease(m_sma_h_4H);
        IndicatorRelease(m_sma_h_D1);
        IndicatorRelease(m_sma_h_W1);
        IndicatorRelease(m_sma_h_MN1);

        ObjectDelete(m_chart_id, m_label_name);
    }
}

//+------------------------------------------------------------------+
//| Calculation                                                      |
//+------------------------------------------------------------------+
void CDashboard::Calculate()
{
    if(!m_dash_on) return;

    // --- Volatility ---
    double atr_val[1], stdev_val[1], sma_atr_val[1];
    CopyBuffer(m_atr_handle, 0, 0, 1, atr_val);
    CopyBuffer(m_stdev_handle, 0, 0, 1, stdev_val);
    CopyBuffer(m_sma_atr_handle, 0, 0, 1, sma_atr_val);

    double top_atr_dev = sma_atr_val[0] + (2 * stdev_val[0]);
    double bottom_atr_dev = sma_atr_val[0] - (2 * stdev_val[0]);
    double dev_range = top_atr_dev - bottom_atr_dev;
    double calc_dev = dev_range > 0 ? (atr_val[0] - bottom_atr_dev) / dev_range : 0;
    m_percent_vol = 40 * calc_dev + 30;

    // --- Volume ---
    MqlRates rates[1];
    CopyRates(_Symbol, _Period, 0, 1, rates);
    m_volume_dash = rates[0].tick_volume;

    // --- RSI ---
    double rsi_val[1];
    CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_val);
    m_rsi_dash = rsi_val[0];

    // --- Sentiment ---
    double ema_val[3];
    CopyBuffer(m_ema_sent_handle, 0, 0, 3, ema_val);
    if(ema_val[0] > ema_val[2]) m_total_sent_txt = "Bullish";
    else if(ema_val[0] < ema_val[2]) m_total_sent_txt = "Bearish";
    else m_total_sent_txt = "Flat";
}

//+------------------------------------------------------------------+
//| Get Trend Helper                                                 |
//+------------------------------------------------------------------+
string CDashboard::GetTrend(int handle)
{
    double sma_val[2];
    if(CopyBuffer(handle, 0, 0, 2, sma_val) < 2) return "-";
    return sma_val[0] > sma_val[1] ? "🟢" : "🔴";
}

//+------------------------------------------------------------------+
//| Drawing                                                          |
//+------------------------------------------------------------------+
void CDashboard::Draw()
{
    if(!m_dash_on) return;

    string oneMTrend = GetTrend(m_sma_h_1M);
    string fiveMTrend = GetTrend(m_sma_h_5M);
    string fifteenMTrend = GetTrend(m_sma_h_15M);
    string thirtyMTrend = GetTrend(m_sma_h_30M);
    string oneHTrend = GetTrend(m_sma_h_1H);
    string twoHTrend = GetTrend(m_sma_h_2H);
    string fourHTrend = GetTrend(m_sma_h_4H);
    string dailyTrend = GetTrend(m_sma_h_D1);
    string weeklyTrend = GetTrend(m_sma_h_W1);
    string monthlyTrend = GetTrend(m_sma_h_MN1);

    string text = "☁️ TABLETA MEGA POWER V3  ☁️\n"
                  "━━━━━━━━━━━━━━━━━\n"
                  "           💵 informacion de mercado 💵\n"
                  "━━━━━━━━━━━━━━━━━\n"
                  "🟡   Volatilidad                     | " + DoubleToString(m_percent_vol, 2) + "%\n"
                  "🟡 Volumen                           | " + DoubleToString(m_volume_dash, 0) + "\n"
                  "🟡 RSI                                           | " + DoubleToString(m_rsi_dash, 2) + "\n"
                  "🟡 Sentimiento mercado | " + m_total_sent_txt + "\n"
                  "━━━━━━━━━━━━━━━━━\n"
                  "               📈 Trend Panel 📉\n"
                  "━━━━━━━━━━━━━━━━━\n"
                  "     1 Minute | " + oneMTrend + "         2 Hour | " + twoHTrend + "\n"
                  "     5 Minute | " + fiveMTrend + "         4 Hour | " + fourHTrend + "\n"
                  "        15 Minute | " + fifteenMTrend + "         Weekly | " + weeklyTrend + "\n"
                  "        30 Minute | " + thirtyMTrend + "       Monthly |     " + monthlyTrend + "\n"
                  "        1 Hour | " + oneHTrend + "                Daily | " + dailyTrend + "\n"
                  "━━━━━━━━━━━━━━━━━\n"
                  "                     🔱CRIPTOM4N 🔱";

    ObjectCreate(m_chart_id, m_label_name, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(m_chart_id, m_label_name, OBJPROP_TEXT, text);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_XDISTANCE, m_dash_dist);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_YDISTANCE, 20);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_BG_COLOR, m_dash_color);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_COLOR, m_dash_text_color);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_FONTSIZE, 8);
    ObjectSetString(m_chart_id, m_label_name, OBJPROP_FONT, "Courier New");
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_BACK, true);

    ChartRedraw(m_chart_id);
}
