//Draws lines on the 15 min signal bar as part of Tom Hopugaards School Run Strategy 

#property indicator_chart_window
#property strict

// Target M15 candle by *broker/server* time
input int      TargetHourServer   = 10;     // 10 -> candle starting 10:15
input int      TargetMinuteServer = 15;     // 15 -> selects 10:15–10:30 M15 bar
input int      DaysToDraw         = 10;     // Includes today
input bool     ExtendToEndOfDay   = true;   // Extend to end of server day
input bool     ExtendInfinitely   = false;  // Ray to the right

// Appearance: theme + optional custom overrides
enum ColorTheme { Theme_BlueRed, Theme_GreenMagenta, Theme_BlackGold, Theme_AquaOrange, Theme_Custom };
input ColorTheme Theme           = Theme_BlueRed;

input color    TopColorCustom    = clrBlue;   // Used only if Theme_Custom
input color    BottomColorCustom = clrRed;    // Used only if Theme_Custom

input ENUM_LINE_STYLE TopStyle    = STYLE_SOLID;
input ENUM_LINE_STYLE BottomStyle = STYLE_SOLID;
input int      LineWidth          = 2;

input bool     DebugLog           = false;

string Prefix = "SchoolRun_";

// ----------------- helpers -----------------
void PickThemeColors(ColorTheme theme, color &topColor, color &bottomColor)
{
   switch(theme)
   {
      case Theme_BlueRed:      topColor = clrBlue;     bottomColor = clrRed;      break;
      case Theme_GreenMagenta: topColor = clrLime;     bottomColor = clrMagenta;  break;
      case Theme_BlackGold:    topColor = clrBlack;    bottomColor = clrGold;     break;
      case Theme_AquaOrange:   topColor = clrAqua;     bottomColor = clrOrange;   break;
      case Theme_Custom:       topColor = TopColorCustom; bottomColor = BottomColorCustom; break;
   }
}

int OnInit(){ return(INIT_SUCCEEDED); }

void OnDeinit(const int reason)
{
   // Uncomment if you want auto-clean on removal:
   // ObjectsDeleteAll(0, Prefix);
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

   color topColor, bottomColor;
   PickThemeColors(Theme, topColor, bottomColor);

   for(int d=0; d<DaysToDraw; d++)
   {
      // Anchor to broker's D1 open
      datetime day_open = iTime(_Symbol, PERIOD_D1, d);
      if(day_open == 0) continue;

      // Target candle by server time
      datetime candle_open  = day_open + TargetHourServer*3600 + TargetMinuteServer*60;
      datetime candle_close = candle_open + 15*60;

      if(candle_close > now) continue;

      int idx = iBarShift(_Symbol, PERIOD_M15, candle_open, true);
      if(idx < 0) continue;

      datetime found_open = iTime(_Symbol, PERIOD_M15, idx);
      if(MathAbs((long)(found_open - candle_open)) > 60) continue;

      double hi = iHigh(_Symbol, PERIOD_M15, idx);
      double lo = iLow(_Symbol, PERIOD_M15, idx);

      datetime day_end = day_open + 86400 - 1;

      string dayKey = TimeToString(day_open, TIME_DATE);
      string nameHi = Prefix + "High_" + dayKey;
      string nameLo = Prefix + "Low_"  + dayKey;

      datetime p1 = candle_close;
      datetime p2 = ExtendToEndOfDay ? day_end : (p1 + 3600);

      CreateOrUpdateHTrend(nameHi, hi, p1, p2, topColor, TopStyle, LineWidth);
      CreateOrUpdateHTrend(nameLo, lo, p1, p2, bottomColor, BottomStyle, LineWidth);

      ObjectSetInteger(0, nameHi, OBJPROP_RAY_RIGHT, ExtendInfinitely);
      ObjectSetInteger(0, nameLo, OBJPROP_RAY_RIGHT, ExtendInfinitely);

      if(DebugLog)
      {
         PrintFormat("SchoolRun: D1_open=%s  target_open=%s  hi=%.5f lo=%.5f",
                     TimeToString(day_open, TIME_DATE|TIME_MINUTES),
                     TimeToString(candle_open, TIME_DATE|TIME_MINUTES),
                     hi, lo);
      }
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
