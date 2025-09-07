//+------------------------------------------------------------------+
//|                                                TPSLManager.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

//--- TP/SL Manager module
class CTPSLManager
{
private:
    //--- Inputs
    int    m_num_tp;
    TPMethod m_tp_method;
    bool   m_show_labels;
    int    m_atr_len;
    double m_atr_risk;
    double m_tp_percent;
    double m_tp_initial_predictum;
    double m_sl_percent;
    int    m_price_decimals;
    bool   m_show_lines;
    LineStyle m_line_style;
    int    m_line_distance;
    int    m_line_thickness;

    //--- Indicator handle
    int    m_atr_handle;

    //--- Trade state
    bool   m_trade_active;
    int    m_trade_direction; // 1 for long, -1 for short
    double m_entry_price;
    double m_sl_price;
    double m_tp_prices[];

    //--- Object names
    string m_entry_label_name, m_sl_label_name;
    string m_tp_label_names[];
    string m_entry_line_name, m_sl_line_name;
    string m_tp_line_names[];

    //--- Chart ID
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

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CTPSLManager::CTPSLManager()
{
    m_trade_active = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CTPSLManager::~CTPSLManager()
{
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void CTPSLManager::Init(long chart_id, int numTP, TPMethod method, bool showLabels, int atrLen, double atrRisk, double tpPercent, double tpInitialPredictum, double slPercent, int decimals, bool showLines, LineStyle style, int distance, int thickness)
{
    m_chart_id = chart_id;
    m_num_tp = numTP;
    m_tp_method = method;
    m_show_labels = showLabels;
    m_atr_len = atrLen;
    m_atr_risk = atrRisk;
    m_tp_percent = tpPercent;
    m_tp_initial_predictum = tpInitialPredictum;
    m_sl_percent = slPercent;
    m_price_decimals = decimals;
    m_show_lines = showLines;
    m_line_style = style;
    m_line_distance = distance;
    m_line_thickness = thickness;

    m_atr_handle = iATR(_Symbol, _Period, m_atr_len);

    // Initialize object names
    m_entry_label_name = "TPSL_EntryLabel_" + (string)m_chart_id;
    m_sl_label_name = "TPSL_SLLabel_" + (string)m_chart_id;
    m_entry_line_name = "TPSL_EntryLine_" + (string)m_chart_id;
    m_sl_line_name = "TPSL_SLLine_" + (string)m_chart_id;
    ArrayResize(m_tp_label_names, m_num_tp);
    ArrayResize(m_tp_line_names, m_num_tp);
    for(int i = 0; i < m_num_tp; i++)
    {
        m_tp_label_names[i] = "TPSL_TPLabel_" + (string)m_chart_id + "_" + (string)i;
        m_tp_line_names[i] = "TPSL_TPLine_" + (string)m_chart_id + "_" + (string)i;
    }
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void CTPSLManager::Deinit()
{
    IndicatorRelease(m_atr_handle);
    ClearObjects();
}

//+------------------------------------------------------------------+
//| ClearObjects                                                     |
//+------------------------------------------------------------------+
void CTPSLManager::ClearObjects()
{
    ObjectDelete(m_chart_id, m_entry_label_name);
    ObjectDelete(m_chart_id, m_sl_label_name);
    ObjectDelete(m_chart_id, m_entry_line_name);
    ObjectDelete(m_chart_id, m_sl_line_name);
    for(int i = 0; i < m_num_tp; i++)
    {
        ObjectDelete(m_chart_id, m_tp_label_names[i]);
        ObjectDelete(m_chart_id, m_tp_line_names[i]);
    }
}

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
void CTPSLManager::Calculate(bool bull_signal, bool bear_signal)
{
    if(!bull_signal && !bear_signal) return;

    ClearObjects();
    m_trade_active = true;
    m_trade_direction = bull_signal ? 1 : -1;

    MqlRates rates[1];
    CopyRates(_Symbol, _Period, 0, 1, rates);
    m_entry_price = rates[0].close;

    ArrayResize(m_tp_prices, m_num_tp);

    if(m_tp_method == TPM_ATR)
    {
        double atr_val[1];
        CopyBuffer(m_atr_handle, 0, 0, 1, atr_val);
        double atr_band = atr_val[0] * m_atr_risk;

        if(m_trade_direction == 1) // Long
        {
            m_sl_price = rates[0].low - atr_band;
            for(int i = 0; i < m_num_tp; i++)
            {
                m_tp_prices[i] = m_entry_price + atr_band * (i + 1);
            }
        }
        else // Short
        {
            m_sl_price = rates[0].high + atr_band;
            for(int i = 0; i < m_num_tp; i++)
            {
                m_tp_prices[i] = m_entry_price - atr_band * (i + 1);
            }
        }
    }
    else if(m_tp_method == TPM_PERCENTAGE)
    {
        double sl_dist = m_entry_price * m_sl_percent / 100.0;
        double tp_dist = m_entry_price * m_tp_percent / 100.0;

        if(m_trade_direction == 1) // Long
        {
            m_sl_price = m_entry_price - sl_dist;
            for(int i = 0; i < m_num_tp; i++)
            {
                m_tp_prices[i] = m_entry_price + tp_dist * (i + 1);
            }
        }
        else // Short
        {
            m_sl_price = m_entry_price + sl_dist;
            for(int i = 0; i < m_num_tp; i++)
            {
                m_tp_prices[i] = m_entry_price - tp_dist * (i + 1);
            }
        }
    }
    else // PREDICTUM
    {
        // This is a simplified version of the logic
        double tp_initial_dist = m_entry_price * m_tp_initial_predictum / 100.0;
        if(m_trade_direction == 1)
        {
             m_sl_price = m_entry_price - (m_entry_price * m_sl_percent / 100.0);
             m_tp_prices[0] = m_entry_price + tp_initial_dist;
             for(int i = 1; i < m_num_tp; i++)
             {
                m_tp_prices[i] = m_tp_prices[i-1] + (m_tp_prices[i-1] - m_entry_price) * 0.618;
             }
        }
        else
        {
             m_sl_price = m_entry_price + (m_entry_price * m_sl_percent / 100.0);
             m_tp_prices[0] = m_entry_price - tp_initial_dist;
             for(int i = 1; i < m_num_tp; i++)
             {
                m_tp_prices[i] = m_tp_prices[i-1] - (m_entry_price - m_tp_prices[i-1]) * 0.618;
             }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw                                                             |
//+------------------------------------------------------------------+
void CTPSLManager::Draw()
{
    if(!m_trade_active || !m_show_labels) return;

    MqlRates rates[1];
    CopyRates(_Symbol, _Period, 0, 1, rates);
    datetime current_time = rates[0].time;

    string dec_format = "%." + (string)m_price_decimals + "f";

    // Draw Entry
    ObjectCreate(m_chart_id, m_entry_label_name, OBJ_TEXT, 0, current_time, m_entry_price);
    ObjectSetString(m_chart_id, m_entry_label_name, OBJPROP_TEXT, "ENTRY 🙈 " + StringFormat(dec_format, m_entry_price));
    ObjectSetInteger(m_chart_id, m_entry_label_name, OBJPROP_COLOR, clrDodgerBlue);
    ObjectSetInteger(m_chart_id, m_entry_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(m_chart_id, m_entry_label_name, OBJPROP_XDISTANCE, m_line_distance);

    // Draw SL
    ObjectCreate(m_chart_id, m_sl_label_name, OBJ_TEXT, 0, current_time, m_sl_price);
    ObjectSetString(m_chart_id, m_sl_label_name, OBJPROP_TEXT, "STOP LOSS💀️ : " + StringFormat(dec_format, m_sl_price));
    ObjectSetInteger(m_chart_id, m_sl_label_name, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(m_chart_id, m_sl_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(m_chart_id, m_sl_label_name, OBJPROP_XDISTANCE, m_line_distance);

    // Draw TPs
    for(int i = 0; i < m_num_tp; i++)
    {
        ObjectCreate(m_chart_id, m_tp_label_names[i], OBJ_TEXT, 0, current_time, m_tp_prices[i]);
        ObjectSetString(m_chart_id, m_tp_label_names[i], OBJPROP_TEXT, "TP" + (string)(i+1) + ") " + StringFormat(dec_format, m_tp_prices[i]) + " | 🎱");
        ObjectSetInteger(m_chart_id, m_tp_label_names[i], OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(m_chart_id, m_tp_label_names[i], OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(m_chart_id, m_tp_label_names[i], OBJPROP_XDISTANCE, m_line_distance);
    }

    if(m_show_lines)
    {
        ENUM_LINE_STYLE style = m_line_style == LS_SOLID ? STYLE_SOLID : m_line_style == LS_DASHED ? STYLE_DASHED : STYLE_DOTTED;

        ObjectCreate(m_chart_id, m_entry_line_name, OBJ_HLINE, 0, 0, m_entry_price);
        ObjectSetInteger(m_chart_id, m_entry_line_name, OBJPROP_COLOR, clrDodgerBlue);
        ObjectSetInteger(m_chart_id, m_entry_line_name, OBJPROP_STYLE, style);
        ObjectSetInteger(m_chart_id, m_entry_line_name, OBJPROP_WIDTH, m_line_thickness);

        ObjectCreate(m_chart_id, m_sl_line_name, OBJ_HLINE, 0, 0, m_sl_price);
        ObjectSetInteger(m_chart_id, m_sl_line_name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(m_chart_id, m_sl_line_name, OBJPROP_STYLE, style);
        ObjectSetInteger(m_chart_id, m_sl_line_name, OBJPROP_WIDTH, m_line_thickness);

        for(int i = 0; i < m_num_tp; i++)
        {
            ObjectCreate(m_chart_id, m_tp_line_names[i], OBJ_HLINE, 0, 0, m_tp_prices[i]);
            ObjectSetInteger(m_chart_id, m_tp_line_names[i], OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(m_chart_id, m_tp_line_names[i], OBJPROP_STYLE, style);
            ObjectSetInteger(m_chart_id, m_tp_line_names[i], OBJPROP_WIDTH, m_line_thickness);
        }
    }
    ChartRedraw(m_chart_id);
}
