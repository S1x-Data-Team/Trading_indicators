#property indicator_chart_window
#property strict

// Afternoon session: draws lines at the high/low of a chosen M15 candle (server time).
input int  DaysToDraw            = 10;        // Days back (incl. today)
input int  TargetHourServer      = 16;        // e.g., 16 -> candle 16:15–16:30
input int  TargetMinuteServer    = 45;        // 15 -> selects :15 M15 bar
input bool ExtendToEndOfDay      = true;      // Extend to server day end
input bool ExtendInfinitely      = false;     // Ray to the right
input bool DebugLog              = false;

// Appearance
input color TopLineColor         = clrBlue;   // High line
input color BottomLineColor      = clrRed;    // Low line
input ENUM_LINE_STYLE TopStyle   = STYLE_SOLID;
input ENUM_LINE_STYLE BottomStyle= STYLE_SOLID;
input int  LineWidth             = 2;

// Cleanup / multi-instance
input bool   RemoveLinesOnDetach = true;      // Delete lines on indicator removal
input string InstanceTag         = "";        // Optional suffix (e.g., "EU_M15")

string BasePrefix = "SR_PM_";
string Prefix;

int OnInit()
{
   Prefix = BasePrefix + (StringLen(InstanceTag) > 0 ? InstanceTag + "_" : "");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(RemoveLinesOnDetach)
      CleanupObjectsByPrefix(Prefix);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   datetime now = TimeCurrent();

   for(int d=0; d<DaysToDraw; d++)
   {
      datetime day_open = iTime(_Symbol, PERIOD_D1, d);
      if(day_open == 0) continue;

      datetime day_end     = day_open + 86400 - 1;
      string   dayKey      = TimeToString(day_open, TIME_DATE);
      datetime candle_open = day_open + TargetHourServer*3600 + TargetMinuteServer*60;
      datetime candle_close= candle_open + 15*60;

      if(candle_close > now) continue;

      int idx = iBarShift(_Symbol, PERIOD_M15, candle_open, true);
      if(idx < 0) continue;

      datetime found_open = iTime(_Symbol, PERIOD_M15, idx);
      if(MathAbs((long)(found_open - candle_open)) > 60) continue;

      double hi = iHigh(_Symbol, PERIOD_M15, idx);
      double lo = iLow(_Symbol, PERIOD_M15, idx);

      string nameHi = Prefix + "High_" + dayKey;
      string nameLo = Prefix + "Low_"  + dayKey;

      datetime p1 = candle_close;
      datetime p2 = ExtendToEndOfDay ? day_end : (p1 + 3600);

      CreateOrUpdateHTrend(nameHi, hi, p1, p2, TopLineColor,    TopStyle,    LineWidth);
      CreateOrUpdateHTrend(nameLo, lo, p1, p2, BottomLineColor, BottomStyle, LineWidth);

      ObjectSetInteger(0, nameHi, OBJPROP_RAY_RIGHT, ExtendInfinitely);
      ObjectSetInteger(0, nameLo, OBJPROP_RAY_RIGHT, ExtendInfinitely);

      if(DebugLog)
         PrintFormat("PM: D1=%s target=%s hi=%.5f lo=%.5f",
                     TimeToString(day_open, TIME_DATE|TIME_MINUTES),
                     TimeToString(candle_open, TIME_DATE|TIME_MINUTES), hi, lo);
   }

   ChartRedraw(0);
   return(rates_total);
}

void CreateOrUpdateHTrend(string name, double price, datetime t1, datetime t2,
                          color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) == -1)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);

   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);

   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, price);
}

void CleanupObjectsByPrefix(string prefix)
{
   int total = (int)ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string name = ObjectName(0, i);
      if(StringLen(name) >= StringLen(prefix) && StringSubstr(name, 0, StringLen(prefix)) == prefix)
         ObjectDelete(0, name);
   }
}
