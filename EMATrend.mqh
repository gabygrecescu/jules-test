//+------------------------------------------------------------------+
//|                                                   EMATrend.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

//--- EMA / Trend module
class CEMATrend
{
private:
    //--- Input parameters
    ENUM_APPLIED_PRICE m_ema_source;
    int    m_ema_period;
    color  m_ema_color;

    //--- Indicator handle
    int    m_ema_handle;
    string m_indicator_shortname;

    //--- Chart ID
    long m_chart_id;

public:
    void CEMATrend();
    ~CEMATrend();
    void Init(long chart_id, ENUM_APPLIED_PRICE ema_source, int ema_period, color ema_color);
    int GetHandle();
    void Deinit();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CEMATrend::CEMATrend()
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CEMATrend::~CEMATrend()
{
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
void CEMATrend::Init(long chart_id, ENUM_APPLIED_PRICE ema_source, int ema_period, color ema_color)
{
    m_chart_id = chart_id;
    m_ema_source = ema_source;
    m_ema_period = ema_period;
    m_ema_color = ema_color;

    m_indicator_shortname = "Moving Average";

    //--- Create indicator on chart
    m_ema_handle = iMA(_Symbol, _Period, m_ema_period, 0, MODE_EMA, m_ema_source);
    if(m_ema_handle != INVALID_HANDLE)
    {
        if(ChartIndicatorAdd(m_chart_id, 0, m_ema_handle))
        {
            IndicatorSetInteger(INDICATOR_COLOR, 0, m_ema_color);
        }
    }
}

//+------------------------------------------------------------------+
//| GetHandle                                                        |
//+------------------------------------------------------------------+
int CEMATrend::GetHandle()
{
    return m_ema_handle;
}


//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void CEMATrend::Deinit()
{
    if(m_ema_handle != INVALID_HANDLE)
    {
        // It's tricky to get the exact shortname to delete, so we release the handle.
        // The terminal should clean up the indicator on deinit.
        IndicatorRelease(m_ema_handle);
    }
}
