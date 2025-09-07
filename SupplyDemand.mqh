//+------------------------------------------------------------------+
//|                                               SupplyDemand.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

#include <ChartObjects\ChartObjectsShapes.mqh>

struct SupplyDemandZone
{
    datetime time;
    double   price_top;
    double   price_bottom;
    int      type; // 1 for supply, -1 for demand
    bool     is_bos;
    string   box_name;
    string   poi_name;
};

//--- Supply/Demand module
class CSupplyDemand
{
private:
    //--- Inputs
    int    m_swing_len;
    int    m_history_to_keep;
    double m_box_width_atr_mult;
    color  m_supply_color;
    color  m_supply_outline_color;
    color  m_demand_color;
    color  m_demand_outline_color;
    color  m_bos_label_color;
    color  m_poi_label_color;

    //--- Indicator handle
    int    m_atr_handle;

    //--- Zone storage
    SupplyDemandZone m_supply_zones[];
    SupplyDemandZone m_demand_zones[];

    //--- Chart ID
    long   m_chart_id;

public:
    void CSupplyDemand();
    ~CSupplyDemand();
    void Init(long chart_id, int swing_len, int history, double box_width, color supply_color, color supply_outline, color demand_color, color demand_outline, color bos_color, color poi_color);
    void CalculateAndDraw();
    void Deinit();

private:
    double GetPivot(int shift, int len, int type); // type 1 for high, -1 for low
    void   AddZone(datetime time, double price, int type);
    void   CheckBOS();
    void   DrawZones();
    void   CleanUpOldObjects();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CSupplyDemand::CSupplyDemand()
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CSupplyDemand::~CSupplyDemand()
{
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void CSupplyDemand::Init(long chart_id, int swing_len, int history, double box_width, color supply_color, color supply_outline, color demand_color, color demand_outline, color bos_color, color poi_color)
{
    m_chart_id = chart_id;
    m_swing_len = swing_len;
    m_history_to_keep = history;
    m_box_width_atr_mult = box_width;
    m_supply_color = supply_color;
    m_supply_outline_color = supply_outline;
    m_demand_color = demand_color;
    m_demand_outline_color = demand_outline;
    m_bos_label_color = bos_color;
    m_poi_label_color = poi_color;

    m_atr_handle = iATR(_Symbol, _Period, 50);
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void CSupplyDemand::Deinit()
{
    IndicatorRelease(m_atr_handle);
    ObjectsDeleteAll(m_chart_id, "SD_");
}

//+------------------------------------------------------------------+
//| Calculate and Draw                                               |
//+------------------------------------------------------------------+
void CSupplyDemand::CalculateAndDraw()
{
    // Find new pivots
    double pivot_high = GetPivot(m_swing_len, m_swing_len, 1);
    double pivot_low = GetPivot(m_swing_len, m_swing_len, -1);

    MqlRates rates[1];
    CopyRates(_Symbol, _Period, m_swing_len, 1, rates);

    if(pivot_high > 0) AddZone(rates[0].time, pivot_high, 1);
    if(pivot_low > 0) AddZone(rates[0].time, pivot_low, -1);

    CheckBOS();
    DrawZones();
    CleanUpOldObjects();
}

//+------------------------------------------------------------------+
//| GetPivot                                                         |
//+------------------------------------------------------------------+
double CSupplyDemand::GetPivot(int shift, int len, int type)
{
    MqlRates rates[];
    int look_around = len * 2 + 1;
    if(CopyRates(_Symbol, _Period, shift, look_around, rates) < look_around) return 0;

    double pivot_val = type == 1 ? rates[len].high : rates[len].low;
    bool is_pivot = true;
    for(int i = 0; i < look_around; i++)
    {
        if(i == len) continue;
        if(type == 1 && rates[i].high > pivot_val)
        {
            is_pivot = false;
            break;
        }
        if(type == -1 && rates[i].low < pivot_val)
        {
            is_pivot = false;
            break;
        }
    }

    return is_pivot ? pivot_val : 0;
}

//+------------------------------------------------------------------+
//| AddZone                                                          |
//+------------------------------------------------------------------+
void CSupplyDemand::AddZone(datetime time, double price, int type)
{
    double atr_val[1];
    CopyBuffer(m_atr_handle, 0, 0, 1, atr_val);
    double box_height = atr_val[0] * (m_box_width_atr_mult / 10.0);

    SupplyDemandZone zone;
    zone.time = time;
    zone.type = type;
    zone.is_bos = false;
    zone.box_name = "SD_Box_" + (string)time + (string)price;
    zone.poi_name = "SD_POI_" + (string)time + (string)price;

    if(type == 1) // Supply
    {
        zone.price_top = price;
        zone.price_bottom = price - box_height;
        ArrayInsert(m_supply_zones, zone, 0);
    }
    else // Demand
    {
        zone.price_bottom = price;
        zone.price_top = price + box_height;
        ArrayInsert(m_demand_zones, zone, 0);
    }
}

//+------------------------------------------------------------------+
//| CheckBOS                                                         |
//+------------------------------------------------------------------+
void CSupplyDemand::CheckBOS()
{
    MqlRates rates[1];
    CopyRates(_Symbol, _Period, 0, 1, rates);
    double current_close = rates[0].close;

    for(int i = 0; i < ArraySize(m_supply_zones); i++)
    {
        if(!m_supply_zones[i].is_bos && current_close > m_supply_zones[i].price_top)
        {
            m_supply_zones[i].is_bos = true;
        }
    }
    for(int i = 0; i < ArraySize(m_demand_zones); i++)
    {
        if(!m_demand_zones[i].is_bos && current_close < m_demand_zones[i].price_bottom)
        {
            m_demand_zones[i].is_bos = true;
        }
    }
}

//+------------------------------------------------------------------+
//| DrawZones                                                        |
//+------------------------------------------------------------------+
void CSupplyDemand::DrawZones()
{
    MqlRates rates[1];
    CopyRates(_Symbol, _Period, 0, 1, rates);
    datetime current_time = rates[0].time;

    for(int i = 0; i < ArraySize(m_supply_zones); i++)
    {
        SupplyDemandZone zone = m_supply_zones[i];
        ObjectCreate(m_chart_id, zone.box_name, OBJ_RECTANGLE, 0, zone.time, zone.price_bottom, current_time + PeriodSeconds(), zone.price_top);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_COLOR, m_supply_outline_color);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BGCOLOR, m_supply_color);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FILL, true);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BACK, true);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_RAY_RIGHT, true);

        if(zone.is_bos)
        {
             ObjectSetString(m_chart_id, zone.box_name, OBJPROP_TEXT, "BOS");
             ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FONTSIZE, 8);
             ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_TEXTCOLOR, m_bos_label_color);
        }
    }

    for(int i = 0; i < ArraySize(m_demand_zones); i++)
    {
        SupplyDemandZone zone = m_demand_zones[i];
        ObjectCreate(m_chart_id, zone.box_name, OBJ_RECTANGLE, 0, zone.time, zone.price_bottom, current_time + PeriodSeconds(), zone.price_top);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_COLOR, m_demand_outline_color);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BGCOLOR, m_demand_color);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FILL, true);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_BACK, true);
        ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_RAY_RIGHT, true);

        if(zone.is_bos)
        {
             ObjectSetString(m_chart_id, zone.box_name, OBJPROP_TEXT, "BOS");
             ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_FONTSIZE, 8);
             ObjectSetInteger(m_chart_id, zone.box_name, OBJPROP_TEXTCOLOR, m_bos_label_color);
        }
    }
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
//| CleanUpOldObjects                                                |
//+------------------------------------------------------------------+
void CSupplyDemand::CleanUpOldObjects()
{
    while(ArraySize(m_supply_zones) > m_history_to_keep)
    {
        int last_idx = ArraySize(m_supply_zones) - 1;
        ObjectDelete(m_chart_id, m_supply_zones[last_idx].box_name);
        ObjectDelete(m_chart_id, m_supply_zones[last_idx].poi_name);
        ArrayRemove(m_supply_zones, last_idx, 1);
    }
    while(ArraySize(m_demand_zones) > m_history_to_keep)
    {
        int last_idx = ArraySize(m_demand_zones) - 1;
        ObjectDelete(m_chart_id, m_demand_zones[last_idx].box_name);
        ObjectDelete(m_chart_id, m_demand_zones[last_idx].poi_name);
        ArrayRemove(m_demand_zones, last_idx, 1);
    }
}
