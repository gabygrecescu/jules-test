//+------------------------------------------------------------------+
//|                                                  AISignals.mqh |
//|                                  Copyright 2025, Google - Jules |
//|                                              https://www.google.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google - Jules"
#property link      "https://www.google.com"

#include <Math\Stat\Stat.mqh>

//--- AI Signals module
class CAISignals
{
private:
    //--- Input parameters
    bool   m_opt_supp_res;
    bool   m_opt_breaks;
    bool   m_opt_psar;
    bool   m_opt_ema_energy;
    bool   m_opt_channel_balance;
    bool   m_opt_auto_tl;

    //--- Indicator handles
    int    m_atr_handle_st;
    int    m_sma_handles[9];
    int    m_sma9_handle;
    int    m_atr_handle_labels;
    int    m_kc_sma_handle;
    int    m_kc_atr_handle;
    int    m_psar_handle;

    //--- Keltner Channel variables
    double m_kc_bands[8];

    //--- Pivot S/R variables
    double m_pivot_high;
    double m_pivot_low;

    //--- Auto Trend Line variables
    double m_lr_slope;
    double m_lr_intercept;
    double m_lr_up_dev;
    double m_lr_dn_dev;

    //--- Supertrend variables
    double m_supertrend_factor;
    double m_supertrend_val[];
    int    m_supertrend_dir[];

    //--- Signal variables
    bool   m_bull_signal;
    bool   m_bear_signal;

    //--- Object names
    string m_buy_label_prefix;
    string m_sell_label_prefix;

    //--- Chart ID
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

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CAISignals::CAISignals()
{
    m_last_calc_bars = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CAISignals::~CAISignals()
{
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
void CAISignals::Init(long chart_id, string sensitivity, bool suppRes, bool breaks, bool usePsar, bool emaEnergy, bool channelBal, bool autoTL)
{
    m_chart_id = chart_id;
    m_opt_supp_res = suppRes;
    m_opt_breaks = breaks;
    m_opt_psar = usePsar;
    m_opt_ema_energy = emaEnergy;
    m_opt_channel_balance = channelBal;
    m_opt_auto_tl = autoTL;

    m_buy_label_prefix = "AISignal_Buy_" + (string)m_chart_id + "_";
    m_sell_label_prefix = "AISignal_Sell_" + (string)m_chart_id + "_";

    if(sensitivity == "Low") m_supertrend_factor = 5.0;
    else if(sensitivity == "Medium") m_supertrend_factor = 2.5;
    else m_supertrend_factor = 2.0;

    m_atr_handle_st = iATR(_Symbol, _Period, 11);
    m_sma9_handle = iMA(_Symbol, _Period, 15, 0, MODE_SMA, PRICE_CLOSE);
    m_atr_handle_labels = iATR(_Symbol, _Period, 30);

    if(m_opt_ema_energy)
    {
        for(int i=0; i<9; i++)
        {
            m_sma_handles[i] = iMA(_Symbol, _Period, 8 + i, 0, MODE_SMA, PRICE_CLOSE);
            if(m_sma_handles[i] != INVALID_HANDLE) ChartIndicatorAdd(m_chart_id, 0, m_sma_handles[i]);
        }
    }

    if(m_opt_channel_balance)
    {
        m_kc_sma_handle = iMA(_Symbol, _Period, 80, 0, MODE_SMA, PRICE_CLOSE);
        m_kc_atr_handle = iATR(_Symbol, _Period, 80);
    }

    if(m_opt_psar)
    {
        m_psar_handle = iSAR(0.02, 0.2);
    }
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void CAISignals::Deinit()
{
    IndicatorRelease(m_atr_handle_st);
    IndicatorRelease(m_sma9_handle);
    IndicatorRelease(m_atr_handle_labels);

    if(m_opt_ema_energy)
    {
        for(int i=0; i<9; i++)
        {
            IndicatorRelease(m_sma_handles[i]);
        }
    }

    if(m_opt_channel_balance)
    {
        IndicatorRelease(m_kc_sma_handle);
        IndicatorRelease(m_kc_atr_handle);
        ObjectsDeleteAll(m_chart_id, "KC_Band_");
    }

    if(m_opt_psar)
    {
        IndicatorRelease(m_psar_handle);
    }

    // Clean up labels
    for(int i = 0; i < Bars(_Symbol, _Period); i++)
    {
        ObjectDelete(m_chart_id, m_buy_label_prefix + (string)i);
        ObjectDelete(m_chart_id, m_sell_label_prefix + (string)i);
    }
}

//+------------------------------------------------------------------+
//| Calculate Supertrend                                             |
//+------------------------------------------------------------------+
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

        if(rates[i].close > m_supertrend_val[i-1])
            m_supertrend_val[i] = MathMax(lower_band, m_supertrend_val[i-1]);
        else
            m_supertrend_val[i] = MathMin(upper_band, m_supertrend_val[i-1]);

        if(rates[i].close > m_supertrend_val[i]) m_supertrend_dir[i] = 1;
        else if(rates[i].close < m_supertrend_val[i]) m_supertrend_dir[i] = -1;
        else m_supertrend_dir[i] = m_supertrend_dir[i-1];
    }
}


//+------------------------------------------------------------------+
//| Calculation                                                      |
//+------------------------------------------------------------------+
void CAISignals::Calculate()
{
    if(m_opt_channel_balance)
    {
        double sma_val[1], atr_val[1];
        CopyBuffer(m_kc_sma_handle, 0, 0, 1, sma_val);
        CopyBuffer(m_kc_atr_handle, 0, 0, 1, atr_val);

        double multipliers[] = {10.5, 9.5, 8, 3};
        for(int i=0; i<4; i++)
        {
            m_kc_bands[i]   = sma_val[0] + multipliers[i] * atr_val[0]; // Upper bands
            m_kc_bands[i+4] = sma_val[0] - multipliers[i] * atr_val[0]; // Lower bands
        }
    }

    CalculateSupertrend();

    int bars = Bars(_Symbol, _Period);
    if(bars < 2) return;

    double close[], sma9[];
    CopyClose(_Symbol, _Period, 0, 2, close);
    CopyBuffer(m_sma9_handle, 0, 0, 2, sma9);

    ArraySetAsSeries(close, true);
    ArraySetAsSeries(sma9, true);

    bool prev_cross_over = close[1] > m_supertrend_val[bars-2] && close[0] <= m_supertrend_val[bars-1];
    m_bull_signal = prev_cross_over && close[0] >= sma9[0];

    bool prev_cross_under = close[1] < m_supertrend_val[bars-2] && close[0] >= m_supertrend_val[bars-1];
    m_bear_signal = prev_cross_under && close[0] <= sma9[0];

    if(m_opt_supp_res)
    {
        m_pivot_high = GetPivot(10, 10, 1);
        m_pivot_low = GetPivot(10, 10, -1);
    }

    if(m_opt_auto_tl)
    {
        double close_data[150];
        CopyClose(_Symbol, _Period, 0, 150, close_data);
        double x_data[];
        ArrayResize(x_data, 150);
        for(int i=0; i<150; i++) x_data[i] = i;

        MathLinearRegression(x_data, close_data, 150, m_lr_intercept, m_lr_slope);

        // Simplified deviation calculation
        m_lr_up_dev = 2 * MathStdDev(close_data);
        m_lr_dn_dev = 2 * MathStdDev(close_data);
    }
}

//+------------------------------------------------------------------+
//| GetPivot helper                                                  |
//+------------------------------------------------------------------+
double CAISignals::GetPivot(int barsL, int barsR, int type)
{
    int look_around = barsL + barsR + 1;
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, look_around, rates) < look_around) return 0;

    double pivot_val = type == 1 ? rates[barsL].high : rates[barsL].low;
    bool is_pivot = true;
    for(int i=0; i<look_around; i++)
    {
        if(i == barsL) continue;
        if(type == 1 && rates[i].high > pivot_val) { is_pivot = false; break; }
        if(type == -1 && rates[i].low < pivot_val) { is_pivot = false; break; }
    }
    return is_pivot ? pivot_val : 0;
}


//+------------------------------------------------------------------+
//| Drawing                                                          |
//+------------------------------------------------------------------+
void CAISignals::Draw()
{
    // --- Support & Resistance ---
    if(m_opt_supp_res)
    {
        if(m_pivot_high > 0)
        {
            ObjectCreate(m_chart_id, "PivotHigh", OBJ_HLINE, 0, 0, m_pivot_high);
            ObjectSetInteger(m_chart_id, "PivotHigh", OBJPROP_COLOR, clrRed);
            ObjectSetInteger(m_chart_id, "PivotHigh", OBJPROP_WIDTH, 2);
        }
        if(m_pivot_low > 0)
        {
            ObjectCreate(m_chart_id, "PivotLow", OBJ_HLINE, 0, 0, m_pivot_low);
            ObjectSetInteger(m_chart_id, "PivotLow", OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(m_chart_id, "PivotLow", OBJPROP_WIDTH, 2);
        }
    }

    // --- Auto Trend Lines ---
    if(m_opt_auto_tl)
    {
        MqlRates rates[150];
        CopyRates(_Symbol, _Period, 0, 150, rates);

        datetime x1 = rates[149].time;
        datetime x2 = rates[0].time;
        double y1 = m_lr_intercept;
        double y2 = m_lr_intercept + m_lr_slope * 149;

        ObjectCreate(m_chart_id, "LR_Middle", OBJ_TREND, 0, x1, y1, x2, y2);
        ObjectCreate(m_chart_id, "LR_Upper", OBJ_TREND, 0, x1, y1 + m_lr_up_dev, x2, y2 + m_lr_up_dev);
        ObjectCreate(m_chart_id, "LR_Lower", OBJ_TREND, 0, x1, y1 - m_lr_dn_dev, x2, y2 - m_lr_dn_dev);

        ObjectSetInteger(m_chart_id, "LR_Middle", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(m_chart_id, "LR_Upper", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(m_chart_id, "LR_Lower", OBJPROP_COLOR, clrGreen);
    }

    // --- PSAR ---
    if(m_opt_psar && m_psar_handle != INVALID_HANDLE)
    {
        ChartIndicatorAdd(m_chart_id, 0, m_psar_handle);
    }

    // --- Channel Balance ---
    if(m_opt_channel_balance)
    {
        for(int i=0; i<8; i++)
        {
            string name = "KC_Band_" + (string)i;
            ObjectCreate(m_chart_id, name, OBJ_HLINE, 0, 0, m_kc_bands[i]);
            ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, i < 4 ? clrRed : clrGreen);
            ObjectSetInteger(m_chart_id, name, OBJPROP_STYLE, STYLE_DOT);
        }
    }

    // --- EMA Energy ---
    if(m_opt_ema_energy)
    {
        double close_val[1];
        CopyClose(_Symbol, _Period, 0, 1, close_val);

        for(int i=0; i<9; i++)
        {
            if(m_sma_handles[i] == INVALID_HANDLE) continue;
            double sma_val[1];
            CopyBuffer(m_sma_handles[i], 0, 0, 1, sma_val);

            color line_color = (close_val[0] >= sma_val[0]) ? C'26,179,213' : C'228,171,26';
            IndicatorSetInteger(m_sma_handles[i], INDICATOR_PROP_COLOR, 0, line_color);
        }
    }

    // --- Signals ---
    int bars = Bars(_Symbol, _Period);
    MqlRates rates[];
    CopyRates(_Symbol, _Period, 0, 2, rates);
    ArraySetAsSeries(rates, true);

    double atr_val[];
    CopyBuffer(m_atr_handle_labels, 0, 0, 1, atr_val);

    if(m_bull_signal)
    {
        string name = m_buy_label_prefix + (string)rates[0].time;
        double price = rates[0].low - atr_val[0] * 1.6;
        ObjectCreate(m_chart_id, name, OBJ_ARROW_BUY, 0, rates[0].time, price);
        ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, C'24, 102, 255');
    }

    if(m_bear_signal)
    {
        string name = m_sell_label_prefix + (string)rates[0].time;
        double price = rates[0].high + atr_val[0] * 1.6;
        ObjectCreate(m_chart_id, name, OBJ_ARROW_SELL, 0, rates[0].time, price);
        ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, C'205, 6, 180');
    }

    ChartRedraw(m_chart_id);
}
