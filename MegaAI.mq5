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

#include <Trade\Trade.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>
#include <Math\Stat\Stat.mqh>

//+------------------------------------------------------------------+
//| CVolumeProfile Class                                             |
//+------------------------------------------------------------------+
class CVolumeProfile
{
private:
    int m_bbars;
    int m_cnum;
    double m_percent;
    color m_poc_color;
    int m_poc_width;
    color m_vup_color;
    color m_vdown_color;
    color m_up_color;
    color m_down_color;
    bool m_show_poc_label;
    double m_levels[];
    double m_volumes[];
    double m_totalvols[];
    int m_poc_index;
    double m_poc_level;
    int m_va_up;
    int m_va_down;
    string m_poc_line_name;
    string m_poc_label_name;
    string m_vol_box_names[];
    long m_chart_id;

public:
    void CVolumeProfile();
    void ~CVolumeProfile();
    void Init(long chart_id, int bbars, int cnum, double percent, color poc_color, int poc_width, color vup_color, color vdown_color, color up_color, color down_color, bool show_poc_label);
    void Calculate();
    void Draw();
    void Deinit();

private:
    double GetVol(double y11, double y12, double y21, double y22, double height, double vol);
};
void CVolumeProfile::CVolumeProfile(){}
void CVolumeProfile::~CVolumeProfile(){}
void CVolumeProfile::Init(long chart_id, int bbars, int cnum, double percent, color poc_color, int poc_width, color vup_color, color vdown_color, color up_color, color down_color, bool show_poc_label)
{
    m_chart_id = chart_id;
    m_bbars = bbars;
    m_cnum = cnum;
    m_percent = percent;
    m_poc_color = poc_color;
    m_poc_width = poc_width;
    m_vup_color = vup_color;
    m_vdown_color = vdown_color;
    m_up_color = up_color;
    m_down_color = down_color;
    m_show_poc_label = show_poc_label;
    m_poc_line_name = "VP_POC_Line_" + (string)m_chart_id;
    m_poc_label_name = "VP_POC_Label_" + (string)m_chart_id;
    ArrayResize(m_vol_box_names, cnum * 2);
    for (int i = 0; i < cnum * 2; i++)
    {
        m_vol_box_names[i] = "VP_Vol_Box_" + (string)m_chart_id + "_" + IntegerToString(i);
    }
}
void CVolumeProfile::Deinit()
{
    ObjectDelete(m_chart_id, m_poc_line_name);
    ObjectDelete(m_chart_id, m_poc_label_name);
    for (int i = 0; i < ArraySize(m_vol_box_names); i++)
    {
        ObjectDelete(m_chart_id, m_vol_box_names[i]);
    }
}
void CVolumeProfile::Calculate()
{
    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 1, m_bbars, rates) < m_bbars) return;
    double top = 0;
    double bot = 1e10;
    for(int i = 0; i < m_bbars; i++)
    {
        if(rates[i].high > top) top = rates[i].high;
        if(rates[i].low < bot) bot = rates[i].low;
    }
    double step = (top - bot) / m_cnum;
    if(step == 0) return;
    ArrayResize(m_levels, m_cnum + 1);
    for (int i = 0; i <= m_cnum; i++) m_levels[i] = bot + step * i;
    ArrayResize(m_volumes, m_cnum * 2);
    ArrayInitialize(m_volumes, 0);
    for (int i = 0; i < m_bbars; i++)
    {
        double body_top = MathMax(rates[i].close, rates[i].open);
        double body_bot = MathMin(rates[i].close, rates[i].open);
        bool itsgreen = rates[i].close >= rates[i].open;
        double topwick = rates[i].high - body_top;
        double bottomwick = body_bot - rates[i].low;
        double body = body_top - body_bot;
        double total_height = 2 * topwick + 2 * bottomwick + body;
        long bar_volume = (long)rates[i].tick_volume;
        if(total_height == 0) continue;
        double bodyvol = body * bar_volume / total_height;
        double topwickvol = 2 * topwick * bar_volume / total_height;
        double bottomwickvol = 2 * bottomwick * bar_volume / total_height;
        for (int j = 0; j < m_cnum; j++)
        {
            m_volumes[j] += (itsgreen ? GetVol(m_levels[j], m_levels[j + 1], body_bot, body_top, body, bodyvol) : 0) + GetVol(m_levels[j], m_levels[j + 1], body_top, rates[i].high, topwick, topwickvol) / 2 + GetVol(m_levels[j], m_levels[j + 1], rates[i].low, body_bot, bottomwick, bottomwickvol) / 2;
            m_volumes[j + m_cnum] += (!itsgreen ? GetVol(m_levels[j], m_levels[j + 1], body_bot, body_top, body, bodyvol) : 0) + GetVol(m_levels[j], m_levels[j + 1], body_top, rates[i].high, topwick, topwickvol) / 2 + GetVol(m_levels[j], m_levels[j + 1], rates[i].low, body_bot, bottomwick, bottomwickvol) / 2;
        }
    }
    ArrayResize(m_totalvols, m_cnum);
    for (int i = 0; i < m_cnum; i++) m_totalvols[i] = m_volumes[i] + m_volumes[i + m_cnum];
    m_poc_index = ArrayMaximum(m_totalvols);
    m_poc_level = (m_levels[m_poc_index] + m_levels[m_poc_index + 1]) / 2;
    double total_sum = ArraySum(m_totalvols);
    double total_max = total_sum * m_percent / 100.0;
    double va_total = m_totalvols[m_poc_index];
    m_va_up = m_poc_index;
    m_va_down = m_poc_index;
    for (int i = 0; i < m_cnum; i++)
    {
        if (va_total >= total_max) break;
        double uppervol = (m_va_up < m_cnum - 1) ? m_totalvols[m_va_up + 1] : 0;
        double lowervol = (m_va_down > 0) ? m_totalvols[m_va_down - 1] : 0;
        if (uppervol == 0 && lowervol == 0) break;
        if (uppervol >= lowervol) { va_total += uppervol; m_va_up++; }
        else { va_total += lowervol; m_va_down--; }
    }
    double maxvol = ArrayMaximum(m_totalvols);
    if (maxvol > 0)
    {
        for (int i = 0; i < m_cnum * 2; i++) m_volumes[i] = m_volumes[i] * 30 / maxvol; // Normalize to max 30 bars width
    }
}
double CVolumeProfile::GetVol(double y11, double y12, double y21, double y22, double height, double vol)
{
    if (height <= 0) return 0;
    return MathMax(0, MathMin(MathMax(y11, y12), MathMax(y21, y22)) - MathMax(MathMin(y11, y12), MathMin(y21, y22))) * vol / height;
}
void CVolumeProfile::Draw()
{
    MqlRates rates[1];
    if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1) return;
    datetime last_bar_time = rates[0].time;
    Deinit();
    datetime time1 = rates[0].time - (m_bbars - 1) * PeriodSeconds();
    for(int i = 0; i < m_cnum; i++)
    {
        datetime time2 = time1 + (int)MathRound(m_volumes[i]) * PeriodSeconds();
        datetime time3 = time2 + (int)MathRound(m_volumes[i + m_cnum]) * PeriodSeconds();
        color up_box_color = (i >= m_va_down && i <= m_va_up) ? m_vup_color : m_up_color;
        ObjectCreate(m_chart_id, m_vol_box_names[i], OBJ_RECTANGLE, 0, time1, m_levels[i], time2, m_levels[i+1]);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i], OBJPROP_COLOR, up_box_color);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i], OBJPROP_FILL, true);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i], OBJPROP_BACK, true);
        color down_box_color = (i >= m_va_down && i <= m_va_up) ? m_vdown_color : m_down_color;
        ObjectCreate(m_chart_id, m_vol_box_names[i + m_cnum], OBJ_RECTANGLE, 0, time2, m_levels[i], time3, m_levels[i+1]);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i + m_cnum], OBJPROP_COLOR, down_box_color);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i + m_cnum], OBJPROP_FILL, true);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i + m_cnum], OBJPROP_BACK, true);
    }
    datetime poc_time1 = last_bar_time - (m_bbars - 1) * PeriodSeconds();
    datetime poc_time2 = poc_time1 + PeriodSeconds();
    ObjectCreate(m_chart_id, m_poc_line_name, OBJ_TREND, 0, poc_time1, m_poc_level, poc_time2, m_poc_level);
    ObjectSetInteger(m_chart_id, m_poc_line_name, OBJPROP_COLOR, m_poc_color);
    ObjectSetInteger(m_chart_id, m_poc_line_name, OBJPROP_WIDTH, m_poc_width);
    ObjectSetInteger(m_chart_id, m_poc_line_name, OBJPROP_RAY_RIGHT, true);
    if(m_show_poc_label)
    {
        datetime label_time = last_bar_time + 15 * PeriodSeconds();
        ObjectCreate(m_chart_id, m_poc_label_name, OBJ_TEXT, 0, label_time, m_poc_level);
        ObjectSetString(m_chart_id, m_poc_label_name, OBJPROP_TEXT, "POC: " + DoubleToString(m_poc_level, _Digits));
        ObjectSetInteger(m_chart_id, m_poc_label_name, OBJPROP_COLOR, m_poc_color);
        ObjectSetInteger(m_chart_id, m_poc_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
    }
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
//| CDashboard Class                                                 |
//+------------------------------------------------------------------+
class CDashboard
{
private:
    bool   m_dash_on;
    int    m_dash_dist;
    color  m_dash_color;
    color  m_dash_text_color;
    int    m_atr_handle;
    int    m_rsi_handle;
    int    m_ema_sent_handle;
    int    m_sma_h_1M, m_sma_h_5M, m_sma_h_15M, m_sma_h_30M, m_sma_h_1H, m_sma_h_2H, m_sma_h_4H, m_sma_h_D1, m_sma_h_W1, m_sma_h_MN1;
    double m_percent_vol;
    double m_volume_dash;
    double m_rsi_dash;
    string m_total_sent_txt;
    string m_label_name;
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
void CDashboard::CDashboard(){}
void CDashboard::~CDashboard(){}
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
        m_atr_handle = iATR(_Symbol, _Period, 14);
        m_rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
        m_ema_sent_handle = iEMA(_Symbol, _Period, 9, 0, PRICE_CLOSE);
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
void CDashboard::Deinit()
{
    if(m_dash_on)
    {
        IndicatorRelease(m_atr_handle);
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
void CDashboard::Calculate()
{
    if(!m_dash_on) return;
    double atr_history[20];
    CopyBuffer(m_atr_handle, 0, 0, 20, atr_history);
    double sma_atr = 0;
    for(int i=0; i<20; i++) sma_atr += atr_history[i];
    sma_atr /= 20.0;
    double std_dev_atr = MathStdDev(atr_history);
    double top_atr_dev = sma_atr + (2 * std_dev_atr);
    double bottom_atr_dev = sma_atr - (2 * std_dev_atr);
    double dev_range = top_atr_dev - bottom_atr_dev;
    m_percent_vol = 40 * (dev_range > 0 ? (atr_history[19] - bottom_atr_dev) / dev_range : 0) + 30;
    MqlRates rates[1];
    CopyRates(_Symbol, _Period, 0, 1, rates);
    m_volume_dash = rates[0].tick_volume;
    double rsi_val[1];
    CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_val);
    m_rsi_dash = rsi_val[0];
    double ema_val[3];
    CopyBuffer(m_ema_sent_handle, 0, 0, 3, ema_val);
    if(ema_val[0] > ema_val[2]) m_total_sent_txt = "Bullish";
    else if(ema_val[0] < ema_val[2]) m_total_sent_txt = "Bearish";
    else m_total_sent_txt = "Flat";
}
string CDashboard::GetTrend(int handle)
{
    double sma_val[2];
    if(CopyBuffer(handle, 0, 0, 2, sma_val) < 2) return "-";
    return sma_val[0] > sma_val[1] ? "🟢" : "🔴";
}
void CDashboard::Draw()
{
    if(!m_dash_on) return;
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
                  "     1 Minute | " + GetTrend(m_sma_h_1M) + "         2 Hour | " + GetTrend(m_sma_h_2H) + "\n"
                  "     5 Minute | " + GetTrend(m_sma_h_5M) + "         4 Hour | " + GetTrend(m_sma_h_4H) + "\n"
                  "        15 Minute | " + GetTrend(m_sma_h_15M) + "         Weekly | " + GetTrend(m_sma_h_W1) + "\n"
                  "        30 Minute | " + GetTrend(m_sma_h_30M) + "       Monthly |     " + GetTrend(m_sma_h_MN1) + "\n"
                  "        1 Hour | " + GetTrend(m_sma_h_1H) + "                Daily | " + GetTrend(m_sma_h_D1) + "\n"
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

//+------------------------------------------------------------------+
//| CEMATrend Class                                                  |
//+------------------------------------------------------------------+
class CEMATrend
{
private:
    ENUM_APPLIED_PRICE m_ema_source;
    int    m_ema_period;
    color  m_ema_color;
    int    m_ema_handle;
    long m_chart_id;
public:
    void CEMATrend();
    ~CEMATrend();
    void Init(long chart_id, ENUM_APPLIED_PRICE ema_source, int ema_period, color ema_color);
    void Deinit();
};
void CEMATrend::CEMATrend(){}
void CEMATrend::~CEMATrend(){}
void CEMATrend::Init(long chart_id, ENUM_APPLIED_PRICE ema_source, int ema_period, color ema_color)
{
    m_chart_id = chart_id;
    m_ema_source = ema_source;
    m_ema_period = ema_period;
    m_ema_color = ema_color;
    m_ema_handle = iMA(_Symbol, _Period, m_ema_period, 0, MODE_EMA, m_ema_source);
    if(m_ema_handle != INVALID_HANDLE)
    {
        if(ChartIndicatorAdd(m_chart_id, 0, m_ema_handle))
        {
            IndicatorSetInteger(m_ema_handle, INDICATOR_PROP_COLOR, 0, m_ema_color);
        }
    }
}
void CEMATrend::Deinit()
{
    if(m_ema_handle != INVALID_HANDLE) IndicatorRelease(m_ema_handle);
}

//+------------------------------------------------------------------+
//| CEMAWave Class                                                   |
//+------------------------------------------------------------------+
class CEMAWave
{
private:
    bool   m_show_ema_wave;
    bool   m_show_grab_candles;
    int    m_ema_wave_length;
    ENUM_APPLIED_PRICE m_ema_wave_center_source;
    int    m_pac_ce_handle;
    int    m_pac_lo_handle;
    int    m_pac_hi_handle;
    string m_bar_color_rect_prefix;
    long m_chart_id;
    static const int BARS_TO_COLOR = 200;
public:
    void CEMAWave();
    ~CEMAWave();
    void Init(long chart_id, bool show_wave, bool show_grab, int wave_len, ENUM_APPLIED_PRICE center_src);
    void CalculateAndDraw();
    void Deinit();
};
void CEMAWave::CEMAWave(){}
void CEMAWave::~CEMAWave(){}
void CEMAWave::Init(long chart_id, bool show_wave, bool show_grab, int wave_len, ENUM_APPLIED_PRICE center_src)
{
    m_chart_id = chart_id;
    m_show_ema_wave = show_wave;
    m_show_grab_candles = show_grab;
    m_ema_wave_length = wave_len;
    m_ema_wave_center_source = center_src;
    m_bar_color_rect_prefix = "EMAWave_BarRect_" + (string)m_chart_id + "_";
    m_pac_ce_handle = iMA(_Symbol, _Period, m_ema_wave_length, 0, MODE_EMA, m_ema_wave_center_source);
    m_pac_lo_handle = iMA(_Symbol, _Period, m_ema_wave_length, 0, MODE_EMA, PRICE_LOW);
    m_pac_hi_handle = iMA(_Symbol, _Period, m_ema_wave_length, 0, MODE_EMA, PRICE_HIGH);
    if(m_show_ema_wave)
    {
        if(m_pac_ce_handle != INVALID_HANDLE) ChartIndicatorAdd(m_chart_id, 0, m_pac_ce_handle);
        if(m_pac_lo_handle != INVALID_HANDLE) ChartIndicatorAdd(m_chart_id, 0, m_pac_lo_handle);
        if(m_pac_hi_handle != INVALID_HANDLE) ChartIndicatorAdd(m_chart_id, 0, m_pac_hi_handle);
    }
}
void CEMAWave::Deinit()
{
    IndicatorRelease(m_pac_ce_handle);
    IndicatorRelease(m_pac_lo_handle);
    IndicatorRelease(m_pac_hi_handle);
    for(int i = 0; i < BARS_TO_COLOR + 5; i++)
    {
        ObjectDelete(m_chart_id, m_bar_color_rect_prefix + (string)i);
    }
}
void CEMAWave::CalculateAndDraw()
{
    if(!m_show_grab_candles) return;
    MqlRates rates[];
    double pac_hi_buff[], pac_lo_buff[];
    if(CopyRates(_Symbol, _Period, 0, BARS_TO_COLOR, rates) < BARS_TO_COLOR) return;
    if(CopyBuffer(m_pac_hi_handle, 0, 0, BARS_TO_COLOR, pac_hi_buff) < BARS_TO_COLOR) return;
    if(CopyBuffer(m_pac_lo_handle, 0, 0, BARS_TO_COLOR, pac_lo_buff) < BARS_TO_COLOR) return;
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(pac_hi_buff, true);
    ArraySetAsSeries(pac_lo_buff, true);
    for(int i = 0; i < BARS_TO_COLOR; i++)
    {
        double close = rates[i].close;
        double open = rates[i].open;
        double pacHi = pac_hi_buff[i];
        double pacLo = pac_lo_buff[i];
        color bColour;
        if(close >= open)
        {
            if(close >= pacHi) bColour = clrLime;
            else if(close <= pacLo) bColour = clrRed;
            else bColour = clrAqua;
        }
        else
        {
            if(close >= pacHi) bColour = clrGreen;
            else if(close <= pacLo) bColour = clrDarkRed;
            else bColour = clrBlue;
        }
        string name = m_bar_color_rect_prefix + (string)i;
        ObjectCreate(m_chart_id, name, OBJ_RECTANGLE, 0, rates[i].time, rates[i].high, rates[i+1].time, rates[i].low);
        ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, bColour);
        ObjectSetInteger(m_chart_id, name, OBJPROP_FILL, true);
        ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, true);
    }
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
//| CAISignals Class                                                 |
//+------------------------------------------------------------------+
class CAISignals
{
private:
    bool   m_opt_supp_res, m_opt_breaks, m_opt_psar, m_opt_ema_energy, m_opt_channel_balance, m_opt_auto_tl;
    int    m_atr_handle_st, m_sma_handles[9], m_sma9_handle, m_atr_handle_labels, m_kc_sma_handle, m_kc_atr_handle, m_psar_handle;
    double m_kc_bands[8], m_pivot_high, m_pivot_low, m_lr_slope, m_lr_intercept, m_lr_up_dev, m_lr_dn_dev, m_supertrend_factor;
    double m_supertrend_val[];
    int    m_supertrend_dir[];
    bool   m_bull_signal, m_bear_signal;
    string m_buy_label_prefix, m_sell_label_prefix;
    long m_chart_id;
    int    m_last_calc_bars;
public:
    void CAISignals();
    ~CAISignals();
    void Init(long chart_id, string sensitivity, bool suppRes, bool breaks, bool usePsar, bool emaEnergy, bool channelBal, bool autoTL);
    void Calculate();
    void Draw();
    void Deinit();
    bool IsBullSignal() { return m_bull_signal; }
    bool IsBearSignal() { return m_bear_signal; }
private:
    void CalculateSupertrend();
    double GetPivot(int barsL, int barsR, int type);
};
void CAISignals::CAISignals(){ m_last_calc_bars = 0; }
void CAISignals::~CAISignals(){}
void CAISignals::Init(long chart_id, string sensitivity, bool suppRes, bool breaks, bool usePsar, bool emaEnergy, bool channelBal, bool autoTL)
{
    m_chart_id = chart_id;
    m_opt_supp_res = suppRes; m_opt_breaks = breaks; m_opt_psar = usePsar; m_opt_ema_energy = emaEnergy; m_opt_channel_balance = channelBal; m_opt_auto_tl = autoTL;
    m_buy_label_prefix = "AISignal_Buy_" + (string)m_chart_id + "_";
    m_sell_label_prefix = "AISignal_Sell_" + (string)m_chart_id + "_";
    if(sensitivity == "Low") m_supertrend_factor = 5.0; else if(sensitivity == "Medium") m_supertrend_factor = 2.5; else m_supertrend_factor = 2.0;
    m_atr_handle_st = iATR(_Symbol, _Period, 11);
    m_sma9_handle = iMA(_Symbol, _Period, 15, 0, MODE_SMA, PRICE_CLOSE);
    m_atr_handle_labels = iATR(_Symbol, _Period, 30);
    if(m_opt_ema_energy) for(int i=0; i<9; i++) { m_sma_handles[i] = iMA(_Symbol, _Period, 8 + i, 0, MODE_SMA, PRICE_CLOSE); if(m_sma_handles[i] != INVALID_HANDLE) ChartIndicatorAdd(m_chart_id, 0, m_sma_handles[i]); }
    if(m_opt_channel_balance) { m_kc_sma_handle = iMA(_Symbol, _Period, 80, 0, MODE_SMA, PRICE_CLOSE); m_kc_atr_handle = iATR(_Symbol, _Period, 80); }
    if(m_opt_psar) { m_psar_handle = iSAR(0.02, 0.2); }
}
void CAISignals::Deinit()
{
    IndicatorRelease(m_atr_handle_st); IndicatorRelease(m_sma9_handle); IndicatorRelease(m_atr_handle_labels);
    if(m_opt_ema_energy) for(int i=0; i<9; i++) IndicatorRelease(m_sma_handles[i]);
    if(m_opt_channel_balance) { IndicatorRelease(m_kc_sma_handle); IndicatorRelease(m_kc_atr_handle); ObjectsDeleteAll(m_chart_id, "KC_Band_"); }
    if(m_opt_psar) IndicatorRelease(m_psar_handle);
    for(int i = 0; i < Bars(_Symbol, _Period); i++) { ObjectDelete(m_chart_id, m_buy_label_prefix + (string)i); ObjectDelete(m_chart_id, m_sell_label_prefix + (string)i); }
}
void CAISignals::CalculateSupertrend()
{
    int bars = Bars(_Symbol, _Period);
    if(bars <= m_last_calc_bars) return;
    m_last_calc_bars = bars;
    ArrayResize(m_supertrend_val, bars);
    ArrayResize(m_supertrend_dir, bars);
    double atr_buff[];
    MqlRates rates[];
    CopyRates(_Symbol, _Period, 0, bars, rates);
    CopyBuffer(m_atr_handle_st, 0, 0, bars, atr_buff);
    for(int i = 1; i < bars; i++)
    {
        double upper_band = rates[i].high + m_supertrend_factor * atr_buff[i];
        double lower_band = rates[i].low - m_supertrend_factor * atr_buff[i];
        if(rates[i].close > m_supertrend_val[i-1]) m_supertrend_val[i] = MathMax(lower_band, m_supertrend_val[i-1]);
        else m_supertrend_val[i] = MathMin(upper_band, m_supertrend_val[i-1]);
        if(rates[i].close > m_supertrend_val[i]) m_supertrend_dir[i] = 1;
        else if(rates[i].close < m_supertrend_val[i]) m_supertrend_dir[i] = -1;
        else m_supertrend_dir[i] = m_supertrend_dir[i-1];
    }
}
void CAISignals::Calculate()
{
    if(m_opt_channel_balance)
    {
        double sma_val[1], atr_val[1];
        CopyBuffer(m_kc_sma_handle, 0, 0, 1, sma_val); CopyBuffer(m_kc_atr_handle, 0, 0, 1, atr_val);
        double multipliers[] = {10.5, 9.5, 8, 3};
        for(int i=0; i<4; i++) { m_kc_bands[i] = sma_val[0] + multipliers[i] * atr_val[0]; m_kc_bands[i+4] = sma_val[0] - multipliers[i] * atr_val[0]; }
    }
    CalculateSupertrend();
    int bars = Bars(_Symbol, _Period);
    if(bars < 2) return;
    double close[], sma9[];
    CopyClose(_Symbol, _Period, 0, 2, close); CopyBuffer(m_sma9_handle, 0, 0, 2, sma9);
    ArraySetAsSeries(close, true); ArraySetAsSeries(sma9, true);
    m_bull_signal = (close[1] > m_supertrend_val[bars-2] && close[0] <= m_supertrend_val[bars-1]) && close[0] >= sma9[0];
    m_bear_signal = (close[1] < m_supertrend_val[bars-2] && close[0] >= m_supertrend_val[bars-1]) && close[0] <= sma9[0];
    if(m_opt_supp_res) { m_pivot_high = GetPivot(10, 10, 1); m_pivot_low = GetPivot(10, 10, -1); }
    if(m_opt_auto_tl)
    {
        double close_data[150]; CopyClose(_Symbol, _Period, 0, 150, close_data);
        double x_data[]; ArrayResize(x_data, 150); for(int i=0; i<150; i++) x_data[i] = i;
        MathLinearRegression(x_data, close_data, 150, m_lr_intercept, m_lr_slope);
        m_lr_up_dev = 2 * MathStdDev(close_data); m_lr_dn_dev = 2 * MathStdDev(close_data);
    }
}
double CAISignals::GetPivot(int barsL, int barsR, int type)
{
    int look_around = barsL + barsR + 1;
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, look_around, rates) < look_around) return 0;
    double pivot_val = type == 1 ? rates[barsL].high : rates[barsL].low;
    for(int i=0; i<look_around; i++)
    {
        if(i == barsL) continue;
        if(type == 1 && rates[i].high > pivot_val) return 0;
        if(type == -1 && rates[i].low < pivot_val) return 0;
    }
    return pivot_val;
}
void CAISignals::Draw()
{
    if(m_opt_supp_res)
    {
        if(m_pivot_high > 0) { ObjectCreate(m_chart_id, "PivotHigh", OBJ_HLINE, 0, 0, m_pivot_high); ObjectSetInteger(m_chart_id, "PivotHigh", OBJPROP_COLOR, clrRed); ObjectSetInteger(m_chart_id, "PivotHigh", OBJPROP_WIDTH, 2); }
        if(m_pivot_low > 0) { ObjectCreate(m_chart_id, "PivotLow", OBJ_HLINE, 0, 0, m_pivot_low); ObjectSetInteger(m_chart_id, "PivotLow", OBJPROP_COLOR, clrGreen); ObjectSetInteger(m_chart_id, "PivotLow", OBJPROP_WIDTH, 2); }
    }
    if(m_opt_auto_tl)
    {
        MqlRates rates[150]; CopyRates(_Symbol, _Period, 0, 150, rates);
        datetime x1 = rates[149].time; datetime x2 = rates[0].time;
        double y1 = m_lr_intercept; double y2 = m_lr_intercept + m_lr_slope * 149;
        ObjectCreate(m_chart_id, "LR_Middle", OBJ_TREND, 0, x1, y1, x2, y2); ObjectSetInteger(m_chart_id, "LR_Middle", OBJPROP_COLOR, clrWhite);
        ObjectCreate(m_chart_id, "LR_Upper", OBJ_TREND, 0, x1, y1 + m_lr_up_dev, x2, y2 + m_lr_up_dev); ObjectSetInteger(m_chart_id, "LR_Upper", OBJPROP_COLOR, clrRed);
        ObjectCreate(m_chart_id, "LR_Lower", OBJ_TREND, 0, x1, y1 - m_lr_dn_dev, x2, y2 - m_lr_dn_dev); ObjectSetInteger(m_chart_id, "LR_Lower", OBJPROP_COLOR, clrGreen);
    }
    if(m_opt_psar && m_psar_handle != INVALID_HANDLE) ChartIndicatorAdd(m_chart_id, 0, m_psar_handle);
    if(m_opt_channel_balance) for(int i=0; i<8; i++) { string name = "KC_Band_" + (string)i; ObjectCreate(m_chart_id, name, OBJ_HLINE, 0, 0, m_kc_bands[i]); ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, i < 4 ? clrRed : clrGreen); ObjectSetInteger(m_chart_id, name, OBJPROP_STYLE, STYLE_DOT); }
    if(m_opt_ema_energy)
    {
        double close_val[1]; CopyClose(_Symbol, _Period, 0, 1, close_val);
        for(int i=0; i<9; i++)
        {
            if(m_sma_handles[i] == INVALID_HANDLE) continue;
            double sma_val[1]; CopyBuffer(m_sma_handles[i], 0, 0, 1, sma_val);
            color line_color = (close_val[0] >= sma_val[0]) ? C'26,179,213' : C'228,171,26';
            IndicatorSetInteger(m_sma_handles[i], INDICATOR_PROP_COLOR, 0, line_color);
        }
    }
    MqlRates rates_sig[2]; CopyRates(_Symbol, _Period, 0, 2, rates_sig); ArraySetAsSeries(rates_sig, true);
    double atr_val_sig[1]; CopyBuffer(m_atr_handle_labels, 0, 0, 1, atr_val_sig);
    if(m_bull_signal) { string name = m_buy_label_prefix + (string)rates_sig[0].time; double price = rates_sig[0].low - atr_val_sig[0] * 1.6; ObjectCreate(m_chart_id, name, OBJ_ARROW_BUY, 0, rates_sig[0].time, price); ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, C'24, 102, 255'); }
    if(m_bear_signal) { string name = m_sell_label_prefix + (string)rates_sig[0].time; double price = rates_sig[0].high + atr_val_sig[0] * 1.6; ObjectCreate(m_chart_id, name, OBJ_ARROW_SELL, 0, rates_sig[0].time, price); ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, C'205, 6, 180'); }
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
//| CTPSLManager Class                                               |
//+------------------------------------------------------------------+
class CTPSLManager
{
private:
    int    m_num_tp; TPMethod m_tp_method; bool   m_show_labels; int    m_atr_len; double m_atr_risk; double m_tp_percent; double m_tp_initial_predictum; double m_sl_percent; int    m_price_decimals; bool   m_show_lines; LineStyle m_line_style; int    m_line_distance; int    m_line_thickness;
    int    m_atr_handle;
    bool   m_trade_active; int    m_trade_direction; double m_entry_price; double m_sl_price; double m_tp_prices[];
    string m_entry_label_name, m_sl_label_name, m_tp_label_names[], m_entry_line_name, m_sl_line_name, m_tp_line_names[];
    long   m_chart_id;
public:
    void CTPSLManager();
    ~CTPSLManager();
    void Init(long chart_id, int numTP, TPMethod method, bool showLabels, int atrLen, double atrRisk, double tpPercent, double tpInitialPredictum, double slPercent, int decimals, bool showLines, LineStyle style, int distance, int thickness);
    void Calculate(bool bull_signal, bool bear_signal);
    void Draw();
    void Deinit();
    double GetSL() { return m_sl_price; }
    double GetTP(int index) { return (index >= 0 && index < m_num_tp) ? m_tp_prices[index] : 0; }
    bool IsTradeActive() { return m_trade_active; }
    int GetTradeDirection() { return m_trade_direction; }
private:
    void ClearObjects();
};
void CTPSLManager::CTPSLManager(){ m_trade_active = false; }
void CTPSLManager::~CTPSLManager(){}
void CTPSLManager::Init(long chart_id, int numTP, TPMethod method, bool showLabels, int atrLen, double atrRisk, double tpPercent, double tpInitialPredictum, double slPercent, int decimals, bool showLines, LineStyle style, int distance, int thickness)
{
    m_chart_id=chart_id; m_num_tp=numTP; m_tp_method=method; m_show_labels=showLabels; m_atr_len=atrLen; m_atr_risk=atrRisk; m_tp_percent=tpPercent; m_tp_initial_predictum=tpInitialPredictum; m_sl_percent=slPercent; m_price_decimals=decimals; m_show_lines=showLines; m_line_style=style; m_line_distance=distance; m_line_thickness=thickness;
    m_atr_handle = iATR(_Symbol, _Period, m_atr_len);
    m_entry_label_name = "TPSL_EntryLabel_" + (string)m_chart_id; m_sl_label_name = "TPSL_SLLabel_" + (string)m_chart_id; m_entry_line_name = "TPSL_EntryLine_" + (string)m_chart_id; m_sl_line_name = "TPSL_SLLine_" + (string)m_chart_id;
    ArrayResize(m_tp_label_names, m_num_tp); ArrayResize(m_tp_line_names, m_num_tp);
    for(int i = 0; i < m_num_tp; i++) { m_tp_label_names[i] = "TPSL_TPLabel_" + (string)m_chart_id + "_" + (string)i; m_tp_line_names[i] = "TPSL_TPLine_" + (string)m_chart_id + "_" + (string)i; }
}
void CTPSLManager::Deinit(){ IndicatorRelease(m_atr_handle); ClearObjects(); }
void CTPSLManager::ClearObjects()
{
    ObjectDelete(m_chart_id, m_entry_label_name); ObjectDelete(m_chart_id, m_sl_label_name); ObjectDelete(m_chart_id, m_entry_line_name); ObjectDelete(m_chart_id, m_sl_line_name);
    for(int i = 0; i < m_num_tp; i++) { ObjectDelete(m_chart_id, m_tp_label_names[i]); ObjectDelete(m_chart_id, m_tp_line_names[i]); }
}
void CTPSLManager::Calculate(bool bull_signal, bool bear_signal)
{
    if(!bull_signal && !bear_signal) return;
    ClearObjects();
    m_trade_active = true; m_trade_direction = bull_signal ? 1 : -1;
    MqlRates rates[1]; CopyRates(_Symbol, _Period, 0, 1, rates); m_entry_price = rates[0].close;
    ArrayResize(m_tp_prices, m_num_tp);
    if(m_tp_method == TPM_ATR)
    {
        double atr_val[1]; CopyBuffer(m_atr_handle, 0, 0, 1, atr_val); double atr_band = atr_val[0] * m_atr_risk;
        if(m_trade_direction == 1) { m_sl_price = rates[0].low - atr_band; for(int i = 0; i < m_num_tp; i++) m_tp_prices[i] = m_entry_price + atr_band * (i + 1); }
        else { m_sl_price = rates[0].high + atr_band; for(int i = 0; i < m_num_tp; i++) m_tp_prices[i] = m_entry_price - atr_band * (i + 1); }
    }
    else if(m_tp_method == TPM_PERCENTAGE)
    {
        double sl_dist = m_entry_price * m_sl_percent / 100.0; double tp_dist = m_entry_price * m_tp_percent / 100.0;
        if(m_trade_direction == 1) { m_sl_price = m_entry_price - sl_dist; for(int i = 0; i < m_num_tp; i++) m_tp_prices[i] = m_entry_price + tp_dist * (i + 1); }
        else { m_sl_price = m_entry_price + sl_dist; for(int i = 0; i < m_num_tp; i++) m_tp_prices[i] = m_entry_price - tp_dist * (i + 1); }
    }
    else // PREDICTUM
    {
        double tp_initial_dist = m_entry_price * m_tp_initial_predictum / 100.0;
        if(m_trade_direction == 1) { m_sl_price = m_entry_price - (m_entry_price * m_sl_percent / 100.0); m_tp_prices[0] = m_entry_price + tp_initial_dist; for(int i = 1; i < m_num_tp; i++) m_tp_prices[i] = m_tp_prices[i-1] + (m_tp_prices[i-1] - m_entry_price) * 0.618; }
        else { m_sl_price = m_entry_price + (m_entry_price * m_sl_percent / 100.0); m_tp_prices[0] = m_entry_price - tp_initial_dist; for(int i = 1; i < m_num_tp; i++) m_tp_prices[i] = m_tp_prices[i-1] - (m_entry_price - m_tp_prices[i-1]) * 0.618; }
    }
}
void CTPSLManager::Draw()
{
    if(!m_trade_active || !m_show_labels) return;
    MqlRates rates[1]; CopyRates(_Symbol, _Period, 0, 1, rates); datetime current_time = rates[0].time;
    string dec_format = "%." + (string)m_price_decimals + "f";
    ObjectCreate(m_chart_id, m_entry_label_name, OBJ_TEXT, 0, current_time, m_entry_price); ObjectSetString(m_chart_id, m_entry_label_name, OBJPROP_TEXT, "ENTRY 🙈 " + StringFormat(dec_format, m_entry_price)); ObjectSetInteger(m_chart_id, m_entry_label_name, OBJPROP_COLOR, clrDodgerBlue); ObjectSetInteger(m_chart_id, m_entry_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT); ObjectSetInteger(m_chart_id, m_entry_label_name, OBJPROP_XDISTANCE, m_line_distance);
    ObjectCreate(m_chart_id, m_sl_label_name, OBJ_TEXT, 0, current_time, m_sl_price); ObjectSetString(m_chart_id, m_sl_label_name, OBJPROP_TEXT, "STOP LOSS💀️ : " + StringFormat(dec_format, m_sl_price)); ObjectSetInteger(m_chart_id, m_sl_label_name, OBJPROP_COLOR, clrRed); ObjectSetInteger(m_chart_id, m_sl_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT); ObjectSetInteger(m_chart_id, m_sl_label_name, OBJPROP_XDISTANCE, m_line_distance);
    for(int i = 0; i < m_num_tp; i++) { ObjectCreate(m_chart_id, m_tp_label_names[i], OBJ_TEXT, 0, current_time, m_tp_prices[i]); ObjectSetString(m_chart_id, m_tp_label_names[i], OBJPROP_TEXT, "TP" + (string)(i+1) + ") " + StringFormat(dec_format, m_tp_prices[i]) + " | 🎱"); ObjectSetInteger(m_chart_id, m_tp_label_names[i], OBJPROP_COLOR, clrGreen); ObjectSetInteger(m_chart_id, m_tp_label_names[i], OBJPROP_ANCHOR, ANCHOR_LEFT); ObjectSetInteger(m_chart_id, m_tp_label_names[i], OBJPROP_XDISTANCE, m_line_distance); }
    if(m_show_lines)
    {
        ENUM_LINE_STYLE style = m_line_style == LS_SOLID ? STYLE_SOLID : m_line_style == LS_DASHED ? STYLE_DASHED : STYLE_DOTTED;
        ObjectCreate(m_chart_id, m_entry_line_name, OBJ_HLINE, 0, 0, m_entry_price); ObjectSetInteger(m_chart_id, m_entry_line_name, OBJPROP_COLOR, clrDodgerBlue); ObjectSetInteger(m_chart_id, m_entry_line_name, OBJPROP_STYLE, style); ObjectSetInteger(m_chart_id, m_entry_line_name, OBJPROP_WIDTH, m_line_thickness);
        ObjectCreate(m_chart_id, m_sl_line_name, OBJ_HLINE, 0, 0, m_sl_price); ObjectSetInteger(m_chart_id, m_sl_line_name, OBJPROP_COLOR, clrRed); ObjectSetInteger(m_chart_id, m_sl_line_name, OBJPROP_STYLE, style); ObjectSetInteger(m_chart_id, m_sl_line_name, OBJPROP_WIDTH, m_line_thickness);
        for(int i = 0; i < m_num_tp; i++) { ObjectCreate(m_chart_id, m_tp_line_names[i], OBJ_HLINE, 0, 0, m_tp_prices[i]); ObjectSetInteger(m_chart_id, m_tp_line_names[i], OBJPROP_COLOR, clrGreen); ObjectSetInteger(m_chart_id, m_tp_line_names[i], OBJPROP_STYLE, style); ObjectSetInteger(m_chart_id, m_tp_line_names[i], OBJPROP_WIDTH, m_line_thickness); }
    }
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
//| CMaxProfit Class                                                 |
//+------------------------------------------------------------------+
class CMaxProfit
{
private:
    int    m_leverage; bool   m_show_labels; int    m_y_pos;
    bool   m_trade_active; int    m_trade_direction; double m_entry_price; double m_peak_price; datetime m_peak_time;
    string m_label_name;
    long   m_chart_id;
public:
    void CMaxProfit();
    ~CMaxProfit();
    void Init(long chart_id, int leverage, bool show_labels, int y_pos);
    void Calculate(bool bull_signal, bool bear_signal);
    void Draw();
    void Deinit();
};
void CMaxProfit::CMaxProfit(){ m_trade_active = false; }
void CMaxProfit::~CMaxProfit(){}
void CMaxProfit::Init(long chart_id, int leverage, bool show_labels, int y_pos) { m_chart_id=chart_id; m_leverage=leverage; m_show_labels=show_labels; m_y_pos=y_pos; m_label_name = "MaxProfit_Label_" + (string)m_chart_id; }
void CMaxProfit::Deinit(){ ObjectDelete(m_chart_id, m_label_name); }
void CMaxProfit::Calculate(bool bull_signal, bool bear_signal)
{
    MqlRates rates[1]; if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1) return;
    if(bull_signal) { m_trade_active=true; m_trade_direction=1; m_entry_price=rates[0].close; m_peak_price=rates[0].high; m_peak_time=rates[0].time; ObjectDelete(m_chart_id, m_label_name); }
    else if(bear_signal) { m_trade_active=true; m_trade_direction=-1; m_entry_price=rates[0].close; m_peak_price=rates[0].low; m_peak_time=rates[0].time; ObjectDelete(m_chart_id, m_label_name); }
    else if(m_trade_active)
    {
        if(m_trade_direction == 1 && rates[0].high > m_peak_price) { m_peak_price=rates[0].high; m_peak_time=rates[0].time; }
        else if(m_trade_direction == -1 && rates[0].low < m_peak_price) { m_peak_price=rates[0].low; m_peak_time=rates[0].time; }
    }
}
void CMaxProfit::Draw()
{
    if(!m_show_labels || !m_trade_active) return;
    double peak_profit_percent = (m_entry_price > 0) ? (MathAbs(m_peak_price - m_entry_price) / m_entry_price) * 100 * m_leverage : 0;
    string text = "Peak Profit: " + DoubleToString(peak_profit_percent, 2) + "%";
    ObjectCreate(m_chart_id, m_label_name, OBJ_TEXT, 0, m_peak_time, m_peak_price);
    ObjectSetString(m_chart_id, m_label_name, OBJPROP_TEXT, text);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_COLOR, C'33,87,243');
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_ANCHOR, m_trade_direction == 1 ? ANCHOR_LEFT : ANCHOR_RIGHT);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_XDISTANCE, m_y_pos);
}

//+------------------------------------------------------------------+
//| CSupplyDemand Class                                              |
//+------------------------------------------------------------------+
struct SupplyDemandZone
{
    datetime time; double price_top; double price_bottom; int type; bool is_bos; string box_name; string poi_name;
};
class CSupplyDemand
{
private:
    int m_swing_len, m_history_to_keep; double m_box_width_atr_mult; color m_supply_color, m_supply_outline_color, m_demand_color, m_demand_outline_color, m_bos_label_color, m_poi_label_color;
    int m_atr_handle;
    SupplyDemandZone m_supply_zones[], m_demand_zones[];
    long m_chart_id;
public:
    void CSupplyDemand();
    ~CSupplyDemand();
    void Init(long chart_id, int swing_len, int history, double box_width, color supply_color, color supply_outline, color demand_color, color demand_outline, color bos_color, color poi_color);
    void CalculateAndDraw();
    void Deinit();
private:
    double GetPivot(int shift, int len, int type);
    void   AddZone(datetime time, double price, int type);
    void   CheckBOS();
    void   DrawZones();
    void   CleanUpOldObjects();
};
void CSupplyDemand::CSupplyDemand(){}
void CSupplyDemand::~CSupplyDemand(){}
void CSupplyDemand::Init(long chart_id, int swing_len, int history, double box_width, color supply_color, color supply_outline, color demand_color, color demand_outline, color bos_color, color poi_color)
{
    m_chart_id=chart_id; m_swing_len=swing_len; m_history_to_keep=history; m_box_width_atr_mult=box_width; m_supply_color=supply_color; m_supply_outline_color=supply_outline; m_demand_color=demand_color; m_demand_outline_color=demand_outline; m_bos_label_color=bos_color; m_poi_label_color=poi_color;
    m_atr_handle = iATR(_Symbol, _Period, 50);
}
void CSupplyDemand::Deinit(){ IndicatorRelease(m_atr_handle); ObjectsDeleteAll(m_chart_id, "SD_"); }
void CSupplyDemand::CalculateAndDraw()
{
    double pivot_high = GetPivot(m_swing_len, m_swing_len, 1);
    double pivot_low = GetPivot(m_swing_len, m_swing_len, -1);
    MqlRates rates[1]; CopyRates(_Symbol, _Period, m_swing_len, 1, rates);
    if(pivot_high > 0) AddZone(rates[0].time, pivot_high, 1);
    if(pivot_low > 0) AddZone(rates[0].time, pivot_low, -1);
    CheckBOS(); DrawZones(); CleanUpOldObjects();
}
double CSupplyDemand::GetPivot(int shift, int len, int type)
{
    MqlRates rates[]; int look_around = len * 2 + 1;
    if(CopyRates(_Symbol, _Period, shift, look_around, rates) < look_around) return 0;
    double pivot_val = type == 1 ? rates[len].high : rates[len].low;
    for(int i = 0; i < look_around; i++) { if(i == len) continue; if(type == 1 && rates[i].high > pivot_val) return 0; if(type == -1 && rates[i].low < pivot_val) return 0; }
    return pivot_val;
}
void CSupplyDemand::AddZone(datetime time, double price, int type)
{
    double atr_val[1]; CopyBuffer(m_atr_handle, 0, 0, 1, atr_val);
    double box_height = atr_val[0] * (m_box_width_atr_mult / 10.0);
    SupplyDemandZone zone;
    zone.time=time; zone.type=type; zone.is_bos=false; zone.box_name="SD_Box_"+(string)time+(string)price; zone.poi_name="SD_POI_"+(string)time+(string)price;
    if(type == 1) { zone.price_top=price; zone.price_bottom=price-box_height; ArrayInsert(m_supply_zones, zone, 0); }
    else { zone.price_bottom=price; zone.price_top=price+box_height; ArrayInsert(m_demand_zones, zone, 0); }
}
void CSupplyDemand::CheckBOS()
{
    MqlRates rates[1]; CopyRates(_Symbol, _Period, 0, 1, rates); double current_close = rates[0].close;
    for(int i = 0; i < ArraySize(m_supply_zones); i++) if(!m_supply_zones[i].is_bos && current_close > m_supply_zones[i].price_top) m_supply_zones[i].is_bos = true;
    for(int i = 0; i < ArraySize(m_demand_zones); i++) if(!m_demand_zones[i].is_bos && current_close < m_demand_zones[i].price_bottom) m_demand_zones[i].is_bos = true;
}
void CSupplyDemand::DrawZones()
{
    MqlRates rates[1]; CopyRates(_Symbol, _Period, 0, 1, rates); datetime current_time = rates[0].time;
    for(int i=0; i<ArraySize(m_supply_zones); i++)
    {
        SupplyDemandZone zone = m_supply_zones[i];
        ObjectCreate(m_chart_id, zone.box_name, OBJ_RECTANGLE, 0, zone.time, zone.price_bottom, current_time+PeriodSeconds(), zone.price_top);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_COLOR, m_supply_outline_color); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BGCOLOR, m_supply_color);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FILL, true); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BACK, true); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_RAY_RIGHT, true);
        if(zone.is_bos) { ObjectSetString(m_chart_id, zone.box_name, OBJPROP_TEXT, "BOS"); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FONTSIZE, 8); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_TEXTCOLOR, m_bos_label_color); }
    }
    for(int i=0; i<ArraySize(m_demand_zones); i++)
    {
        SupplyDemandZone zone = m_demand_zones[i];
        ObjectCreate(m_chart_id, zone.box_name, OBJ_RECTANGLE, 0, zone.time, zone.price_bottom, current_time+PeriodSeconds(), zone.price_top);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_COLOR, m_demand_outline_color); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BGCOLOR, m_demand_color);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FILL, true); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BACK, true); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_RAY_RIGHT, true);
        if(zone.is_bos) { ObjectSetString(m_chart_id, zone.box_name, OBJPROP_TEXT, "BOS"); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FONTSIZE, 8); ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_TEXTCOLOR, m_bos_label_color); }
    }
    ChartRedraw(m_chart_id);
}
void CSupplyDemand::CleanUpOldObjects()
{
    while(ArraySize(m_supply_zones) > m_history_to_keep) { int last_idx=ArraySize(m_supply_zones)-1; ObjectDelete(m_chart_id, m_supply_zones[last_idx].box_name); ObjectDelete(m_chart_id, m_supply_zones[last_idx].poi_name); ArrayRemove(m_supply_zones, last_idx, 1); }
    while(ArraySize(m_demand_zones) > m_history_to_keep) { int last_idx=ArraySize(m_demand_zones)-1; ObjectDelete(m_chart_id, m_demand_zones[last_idx].box_name); ObjectDelete(m_chart_id, m_demand_zones[last_idx].poi_name); ArrayRemove(m_demand_zones, last_idx, 1); }
}

//+------------------------------------------------------------------+
//| CZigZag Class                                                    |
//+------------------------------------------------------------------+
class CZigZag
{
private:
    bool m_show_zigzag; color m_zigzag_color; int m_swing_len;
    bool m_dir_up; double m_last_low, m_last_high; datetime m_time_low, m_time_high;
    string m_line_prefix; int m_line_counter;
    long m_chart_id;
public:
    void CZigZag();
    ~CZigZag();
    void Init(long chart_id, bool show, color c, int swing_len);
    void CalculateAndDraw();
    void Deinit();
};
void CZigZag::CZigZag(){ m_dir_up=false; m_last_low=1e10; m_last_high=0; m_line_counter=0; }
void CZigZag::~CZigZag(){}
void CZigZag::Init(long chart_id, bool show, color c, int swing_len) { m_chart_id=chart_id; m_show_zigzag=show; m_zigzag_color=c; m_swing_len=swing_len; m_line_prefix="ZigZag_Line_"+(string)m_chart_id+"_"; }
void CZigZag::Deinit(){ ObjectsDeleteAll(m_chart_id, m_line_prefix); }
void CZigZag::CalculateAndDraw()
{
    if(!m_show_zigzag) return;
    int lookback = m_swing_len * 2 + 1;
    MqlRates rates[]; if(CopyRates(_Symbol, _Period, 0, lookback, rates) < lookback) return;
    ArraySetAsSeries(rates, true);
    double h=rates[0].high, l=rates[0].low;
    for(int i=1; i<lookback; i++) { if(rates[i].high > h) h=rates[i].high; if(rates[i].low < l) l=rates[i].low; }
    bool is_max = (h == rates[m_swing_len].high);
    bool is_min = (l == rates[m_swing_len].low);
    datetime current_pivot_time = rates[m_swing_len].time;
    if(m_dir_up)
    {
        if(is_min && rates[m_swing_len].low < m_last_low) { m_last_low=rates[m_swing_len].low; m_time_low=current_pivot_time; }
        if(is_max && rates[m_swing_len].high > m_last_low) { m_last_high=rates[m_swing_len].high; m_time_high=current_pivot_time; m_dir_up=false; string name=m_line_prefix+(string)m_line_counter++; ObjectCreate(m_chart_id, name, OBJ_TREND, 0, m_time_low, m_last_low, m_time_high, m_last_high); ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, m_zigzag_color); ObjectSetInteger(m_chart_id, name, OBJPROP_WIDTH, 2); }
    }
    else
    {
        if(is_max && rates[m_swing_len].high > m_last_high) { m_last_high=rates[m_swing_len].high; m_time_high=current_pivot_time; }
        if(is_min && rates[m_swing_len].low < m_last_high) { m_last_low=rates[m_swing_len].low; m_time_low=current_pivot_time; m_dir_up=true; string name=m_line_prefix+(string)m_line_counter++; ObjectCreate(m_chart_id, name, OBJ_TREND, 0, m_time_high, m_last_high, m_time_low, m_last_low); ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, m_zigzag_color); ObjectSetInteger(m_chart_id, name, OBJPROP_WIDTH, 2); }
    }
}

//+------------------------------------------------------------------+
//| Expert Advisor Core                                              |
//+------------------------------------------------------------------+
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
int OnInit()
{
   g_volume_profile.Init(ChartID(), VP_NumberOfBars, VP_RowSize, VP_ValueAreaPercent, VP_POC_Color, VP_POC_Width, VP_ValueAreaUp, VP_ValueAreaDown, VP_UpVolumeColor, VP_DownVolumeColor, VP_ShowPOCLabel);
   g_dashboard.Init(ChartID(), Dash_On, Dash_Distance, Dash_Background, Dash_TextColor);
   g_ema_trend.Init(ChartID(), EMA_Source, EMA200_Period, EMA_Color);
   g_ema_wave.Init(ChartID(), Show_EMA_Wave, Show_Grab_Candles, EMA_Wave_Length, EMA_Wave_Center_Source);
   string sensitivity_str;
   switch(Sensitivity)
   {
      case SENSITIVITY_LOW: sensitivity_str = "Low"; break;
      case SENSITIVITY_MEDIUM: sensitivity_str = "Medium"; break;
      case SENSITIVITY_HIGH: sensitivity_str = "High"; break;
   }
   g_ai_signals.Init(ChartID(), sensitivity_str, Opt_SupportResistance, Opt_Breaks, Opt_PSAR, Opt_EMA_Energy, Opt_ChannelBalance, Opt_AutoTrendLines);
   g_tpsl_manager.Init(ChartID(), TP_NumberLevels, TP_CalcMethod, Levels_ShowLabels, ATR_Length_TP, Risk_Trade, TP_Percent, TP_Initial_Predictum, SL_Percent, Price_Decimals, Show_TPSL_Lines, TPSL_LineStyle, TPSL_Distance, TPSL_LineThickness);
   g_max_profit.Init(ChartID(), MaxProfit_LeverageX, MaxProfit_ShowLabels, MaxProfit_YLabelPos);
   g_supply_demand.Init(ChartID(), SD_SwingLen, SD_HistoryToKeep, SD_BoxWidth, VS_SupplyColor, VS_SupplyOutline, VS_DemandColor, VS_DemandOutline, VS_BOSLabelColor, VS_POILabelColor);
   g_zigzag.Init(ChartID(), VS_ShowZigZag, VS_ZigZagColor, SD_SwingLen);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_volume_profile.Deinit();
   g_dashboard.Deinit();
   g_ema_trend.Deinit();
   g_ema_wave.Deinit();
   g_ai_signals.Deinit();
   g_tpsl_manager.Deinit();
   g_max_profit.Deinit();
   g_supply_demand.Deinit();
   g_zigzag.Deinit();
}
//+------------------------------------------------------------------+
void OnTick()
{
   MqlRates rates[1];
   if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1) return;
   if(rates[0].time != g_last_bar_time)
   {
      g_last_bar_time = rates[0].time;
      g_volume_profile.Calculate();
      g_dashboard.Calculate();
      g_ema_wave.CalculateAndDraw();
      g_ai_signals.Calculate();
      g_tpsl_manager.Calculate(g_ai_signals.IsBullSignal(), g_ai_signals.IsBearSignal());
      g_max_profit.Calculate(g_ai_signals.IsBullSignal(), g_ai_signals.IsBearSignal());
      g_supply_demand.CalculateAndDraw();
      g_zigzag.CalculateAndDraw();
      g_volume_profile.Draw();
      g_dashboard.Draw();
      g_ai_signals.Draw();
      g_tpsl_manager.Draw();
      g_max_profit.Draw();
      if(PositionsTotal() == 0)
      {
         if(g_ai_signals.IsBullSignal()) trade.Buy(LotSize, NULL, 0, g_tpsl_manager.GetSL(), g_tpsl_manager.GetTP(0), "MegaAI Buy");
         else if(g_ai_signals.IsBearSignal()) trade.Sell(LotSize, NULL, 0, g_tpsl_manager.GetSL(), g_tpsl_manager.GetTP(0), "MegaAI Sell");
      }
   }
}
//+------------------------------------------------------------------+
