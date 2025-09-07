//+------------------------------------------------------------------+
//|                                              VolumeProfile.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Volume Profile module
class CVolumeProfile
{
private:
    //--- Input parameters
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

    //--- Calculated data
    double m_levels[];
    double m_volumes[];
    double m_totalvols[];
    int m_poc_index;
    double m_poc_level;
    int m_va_up;
    int m_va_down;

    //--- Object names
    string m_poc_line_name;
    string m_poc_label_name;
    string m_vol_box_names[];

    //--- Chart ID
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

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CVolumeProfile::CVolumeProfile()
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CVolumeProfile::~CVolumeProfile()
{
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void CVolumeProfile::Deinit()
{
    ObjectDelete(m_chart_id, m_poc_line_name);
    ObjectDelete(m_chart_id, m_poc_label_name);
    for (int i = 0; i < ArraySize(m_vol_box_names); i++)
    {
        ObjectDelete(m_chart_id, m_vol_box_names[i]);
    }
}

//+------------------------------------------------------------------+
//| Calculation                                                      |
//+------------------------------------------------------------------+
void CVolumeProfile::Calculate()
{
    // --- Get historical data ---
    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 1, m_bbars, rates) < m_bbars)
    {
        Print("Error copying rates for Volume Profile calculation");
        return;
    }

    // --- Find top and bottom ---
    double top = 0;
    double bot = 1e10; // A large number
    for(int i = 0; i < m_bbars; i++)
    {
        if(rates[i].high > top) top = rates[i].high;
        if(rates[i].low < bot) bot = rates[i].low;
    }

    double step = (top - bot) / m_cnum;
    if(step == 0) return;

    // --- Calculate levels ---
    ArrayResize(m_levels, m_cnum + 1);
    for (int i = 0; i <= m_cnum; i++)
    {
        m_levels[i] = bot + step * i;
    }

    // --- Calculate volume for each level ---
    ArrayResize(m_volumes, m_cnum * 2);
    ArrayInitialize(m_volumes, 0);

    MqlTick ticks[];
    for (int i = 0; i < m_bbars; i++)
    {
        double body_top = MathMax(rates[i].close, rates[i].open);
        double body_bot = MathMin(rates[i].close, rates[i].open);
        bool itsgreen = rates[i].close >= rates[i].open;

        double topwick = rates[i].high - body_top;
        double bottomwick = body_bot - rates[i].low;
        double body = body_top - body_bot;
        double total_height = topwick + bottomwick + body;

        long bar_volume = (long)rates[i].tick_volume;
        if(total_height == 0) continue;

        double bodyvol = body * bar_volume / total_height;
        double topwickvol = topwick * bar_volume / total_height;
        double bottomwickvol = bottomwick * bar_volume / total_height;

        for (int j = 0; j < m_cnum; j++)
        {
            double up_vol = (itsgreen ? GetVol(m_levels[j], m_levels[j + 1], body_bot, body_top, body, bodyvol) : 0)
                            + GetVol(m_levels[j], m_levels[j + 1], body_top, rates[i].high, topwick, topwickvol) / 2
                            + GetVol(m_levels[j], m_levels[j + 1], rates[i].low, body_bot, bottomwick, bottomwickvol) / 2;
            m_volumes[j] += up_vol;

            double down_vol = (!itsgreen ? GetVol(m_levels[j], m_levels[j + 1], body_bot, body_top, body, bodyvol) : 0)
                              + GetVol(m_levels[j], m_levels[j + 1], body_top, rates[i].high, topwick, topwickvol) / 2
                              + GetVol(m_levels[j], m_levels[j + 1], rates[i].low, body_bot, bottomwick, bottomwickvol) / 2;
            m_volumes[j + m_cnum] += down_vol;
        }
    }

    // --- Calculate total volumes and POC ---
    ArrayResize(m_totalvols, m_cnum);
    for (int i = 0; i < m_cnum; i++)
    {
        m_totalvols[i] = m_volumes[i] + m_volumes[i + m_cnum];
    }
    m_poc_index = ArrayMaximum(m_totalvols);
    m_poc_level = (m_levels[m_poc_index] + m_levels[m_poc_index + 1]) / 2;

    // --- Calculate value area ---
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
        if (uppervol >= lowervol)
        {
            va_total += uppervol;
            m_va_up++;
        }
        else
        {
            va_total += lowervol;
            m_va_down--;
        }
    }

    // --- Normalize volumes for drawing ---
    double maxvol = ArrayMaximum(m_totalvols);
    if (maxvol > 0)
    {
        for (int i = 0; i < m_cnum * 2; i++)
        {
            m_volumes[i] = m_volumes[i] * m_bbars / (3 * maxvol);
        }
    }
}

//+------------------------------------------------------------------+
//| Get Volume Helper                                                |
//+------------------------------------------------------------------+
double CVolumeProfile::GetVol(double y11, double y12, double y21, double y22, double height, double vol)
{
    if (height <= 0) return 0;
    double intersection = MathMax(0, MathMin(MathMax(y11, y12), MathMax(y21, y22)) - MathMax(MathMin(y11, y12), MathMin(y21, y22)));
    return intersection * vol / height;
}

//+------------------------------------------------------------------+
//| Drawing                                                          |
//+------------------------------------------------------------------+
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
        ObjectSetInteger(m_chart_id, m_vol_box_names[i], OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i], OBJPROP_FILL, true);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i], OBJPROP_BACK, true);

        color down_box_color = (i >= m_va_down && i <= m_va_up) ? m_vdown_color : m_down_color;
        ObjectCreate(m_chart_id, m_vol_box_names[i + m_cnum], OBJ_RECTANGLE, 0, time2, m_levels[i], time3, m_levels[i+1]);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i + m_cnum], OBJPROP_COLOR, down_box_color);
        ObjectSetInteger(m_chart_id, m_vol_box_names[i + m_cnum], OBJPROP_STYLE, STYLE_SOLID);
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
