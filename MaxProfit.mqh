//+------------------------------------------------------------------+
//|                                                  MaxProfit.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Max Profit module
class CMaxProfit
{
private:
    //--- Inputs
    int    m_leverage;
    bool   m_show_labels;
    int    m_y_pos;

    //--- State
    bool   m_trade_active;
    int    m_trade_direction; // 1 for long, -1 for short
    double m_entry_price;
    double m_peak_price;
    datetime m_peak_time;

    //--- Object name
    string m_label_name;

    //--- Chart ID
    long   m_chart_id;

public:
    void CMaxProfit();
    ~CMaxProfit();
    void Init(long chart_id, int leverage, bool show_labels, int y_pos);
    void Calculate(bool bull_signal, bool bear_signal);
    void Draw();
    void Deinit();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CMaxProfit::CMaxProfit()
{
    m_trade_active = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CMaxProfit::~CMaxProfit()
{
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void CMaxProfit::Init(long chart_id, int leverage, bool show_labels, int y_pos)
{
    m_chart_id = chart_id;
    m_leverage = leverage;
    m_show_labels = show_labels;
    m_y_pos = y_pos;

    m_label_name = "MaxProfit_Label_" + (string)m_chart_id;
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void CMaxProfit::Deinit()
{
    ObjectDelete(m_chart_id, m_label_name);
}

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
void CMaxProfit::Calculate(bool bull_signal, bool bear_signal)
{
    MqlRates rates[1];
    if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1) return;

    if(bull_signal)
    {
        m_trade_active = true;
        m_trade_direction = 1;
        m_entry_price = rates[0].close;
        m_peak_price = rates[0].high;
        m_peak_time = rates[0].time;
        ObjectDelete(m_chart_id, m_label_name);
    }
    else if(bear_signal)
    {
        m_trade_active = true;
        m_trade_direction = -1;
        m_entry_price = rates[0].close;
        m_peak_price = rates[0].low;
        m_peak_time = rates[0].time;
        ObjectDelete(m_chart_id, m_label_name);
    }
    else if(m_trade_active)
    {
        if(m_trade_direction == 1 && rates[0].high > m_peak_price)
        {
            m_peak_price = rates[0].high;
            m_peak_time = rates[0].time;
        }
        else if(m_trade_direction == -1 && rates[0].low < m_peak_price)
        {
            m_peak_price = rates[0].low;
            m_peak_time = rates[0].time;
        }
    }
}

//+------------------------------------------------------------------+
//| Draw                                                             |
//+------------------------------------------------------------------+
void CMaxProfit::Draw()
{
    if(!m_show_labels || !m_trade_active) return;

    double peak_profit_percent = 0;
    if(m_entry_price > 0)
    {
        peak_profit_percent = (MathAbs(m_peak_price - m_entry_price) / m_entry_price) * 100 * m_leverage;
    }
    string text = "Peak Profit: " + DoubleToString(peak_profit_percent, 2) + "%";

    ObjectCreate(m_chart_id, m_label_name, OBJ_TEXT, 0, m_peak_time, m_peak_price);
    ObjectSetString(m_chart_id, m_label_name, OBJPROP_TEXT, text);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_COLOR, C'33,87,243');
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_ANCHOR, m_trade_direction == 1 ? ANCHOR_LEFT : ANCHOR_RIGHT);
    ObjectSetInteger(m_chart_id, m_label_name, OBJPROP_XDISTANCE, m_y_pos);
}
