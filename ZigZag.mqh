//+------------------------------------------------------------------+
//|                                                     ZigZag.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

#include <ChartObjects\ChartObjectsLines.mqh>

//--- ZigZag module
class CZigZag
{
private:
    //--- Inputs
    bool  m_show_zigzag;
    color m_zigzag_color;
    int   m_swing_len;

    //--- State
    bool     m_dir_up;
    double   m_last_low;
    double   m_last_high;
    datetime m_time_low;
    datetime m_time_high;

    //--- Object management
    string   m_line_prefix;
    int      m_line_counter;

    //--- Chart ID
    long     m_chart_id;

public:
    void CZigZag();
    ~CZigZag();
    void Init(long chart_id, bool show, color c, int swing_len);
    void CalculateAndDraw();
    void Deinit();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CZigZag::CZigZag()
{
    m_dir_up = false;
    m_last_low = 1e10;
    m_last_high = 0;
    m_line_counter = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CZigZag::~CZigZag()
{
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void CZigZag::Init(long chart_id, bool show, color c, int swing_len)
{
    m_chart_id = chart_id;
    m_show_zigzag = show;
    m_zigzag_color = c;
    m_swing_len = swing_len;
    m_line_prefix = "ZigZag_Line_" + (string)m_chart_id + "_";
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void CZigZag::Deinit()
{
    ObjectsDeleteAll(m_chart_id, m_line_prefix);
}

//+------------------------------------------------------------------+
//| Calculate and Draw                                               |
//+------------------------------------------------------------------+
void CZigZag::CalculateAndDraw()
{
    if(!m_show_zigzag) return;

    int lookback = m_swing_len * 2 + 1;
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, lookback, rates) < lookback) return;

    ArraySetAsSeries(rates, true);

    double h = rates[0].high;
    double l = rates[0].low;
    for(int i = 1; i < lookback; i++)
    {
        if(rates[i].high > h) h = rates[i].high;
        if(rates[i].low < l) l = rates[i].low;
    }

    bool is_max = (h == rates[m_swing_len].high);
    bool is_min = (l == rates[m_swing_len].low);

    datetime current_pivot_time = rates[m_swing_len].time;

    if(m_dir_up)
    {
        if(is_min && rates[m_swing_len].low < m_last_low)
        {
            m_last_low = rates[m_swing_len].low;
            m_time_low = current_pivot_time;
        }
        if(is_max && rates[m_swing_len].high > m_last_low)
        {
            m_last_high = rates[m_swing_len].high;
            m_time_high = current_pivot_time;
            m_dir_up = false;

            string name = m_line_prefix + (string)m_line_counter++;
            ObjectCreate(m_chart_id, name, OBJ_TREND, 0, m_time_low, m_last_low, m_time_high, m_last_high);
            ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, m_zigzag_color);
            ObjectSetInteger(m_chart_id, name, OBJPROP_WIDTH, 2);
        }
    }
    else // dirDown
    {
        if(is_max && rates[m_swing_len].high > m_last_high)
        {
            m_last_high = rates[m_swing_len].high;
            m_time_high = current_pivot_time;
        }
        if(is_min && rates[m_swing_len].low < m_last_high)
        {
            m_last_low = rates[m_swing_len].low;
            m_time_low = current_pivot_time;
            m_dir_up = true;

            string name = m_line_prefix + (string)m_line_counter++;
            ObjectCreate(m_chart_id, name, OBJ_TREND, 0, m_time_high, m_last_high, m_time_low, m_last_low);
            ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, m_zigzag_color);
            ObjectSetInteger(m_chart_id, name, OBJPROP_WIDTH, 2);
        }
    }
}
