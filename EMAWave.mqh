//+------------------------------------------------------------------+
//|                                                    EMAWave.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

//--- EMA Wave & GRaB module
class CEMAWave
{
private:
    //--- Input parameters
    bool   m_show_ema_wave;
    bool   m_show_grab_candles;
    int    m_ema_wave_length;
    ENUM_APPLIED_PRICE m_ema_wave_center_source;

    //--- Indicator handles
    int    m_pac_ce_handle;
    int    m_pac_lo_handle;
    int    m_pac_hi_handle;

    //--- Object names
    string m_bar_color_rect_prefix;

    //--- Chart ID
    long m_chart_id;

    //--- Constants for bar coloring
    static const int BARS_TO_COLOR = 200;

public:
    void CEMAWave();
    ~CEMAWave();
    void Init(long chart_id, bool show_wave, bool show_grab, int wave_len, ENUM_APPLIED_PRICE center_src);
    void CalculateAndDraw();
    void Deinit();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CEMAWave::CEMAWave()
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CEMAWave::~CEMAWave()
{
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void CEMAWave::Deinit()
{
    IndicatorRelease(m_pac_ce_handle);
    IndicatorRelease(m_pac_lo_handle);
    IndicatorRelease(m_pac_hi_handle);

    for(int i = 0; i < BARS_TO_COLOR + 5; i++) // A bit of buffer
    {
        ObjectDelete(m_chart_id, m_bar_color_rect_prefix + (string)i);
    }
}

//+------------------------------------------------------------------+
//| Calculate and Draw                                               |
//+------------------------------------------------------------------+
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
        if(close >= open) // Bullish bar
        {
            if(close >= pacHi) bColour = clrLime;
            else if(close <= pacLo) bColour = clrRed;
            else bColour = clrAqua;
        }
        else // Bearish bar
        {
            if(close >= pacHi) bColour = clrGreen;
            else if(close <= pacLo) bColour = clrDarkRed;
            else bColour = clrBlue;
        }

        string name = m_bar_color_rect_prefix + (string)i;
        ObjectCreate(m_chart_id, name, OBJ_RECTANGLE, 0, rates[i].time, rates[i].high, rates[i+1].time, rates[i].low);
        ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, bColour);
        ObjectSetInteger(m_chart_id, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(m_chart_id, name, OBJPROP_FILL, true);
        ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, true);
    }
    ChartRedraw(m_chart_id);
}
