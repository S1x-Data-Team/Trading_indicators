//+------------------------------------------------------------------+
//|                                              DiscordNotifier.mq5 |
//|                Sends MT5 trade events to Discord (webhook)       |
//+------------------------------------------------------------------+
#property strict
#property version   "1.4"
#property description "Relays live trade events (opens/closes/mods) to a Discord channel via webhook."

// ------------ Inputs ------------
input string  InpWebhookURL        = "https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX";
input string  InpBotName           = "MT5 Trade Bot";
input string  InpAvatarURL         = "";
input bool    InpNotifyOpen        = true;     // notify new position opens
input bool    InpNotifyClose       = true;     // notify full/partial closes
input bool    InpNotifyModify      = false;    // notify SL/TP modifications
input bool    InpIncludeSLTP       = true;     // include SL/TP in message
input bool    InpIncludeAccount    = true;     // include account info line
input bool    InpIncludeMagic      = true;     // include magic number
input int     InpHttpTimeoutMs     = 4000;     // WebRequest timeout ms
input bool    InpSendStartupPing   = true;     // send a "bot online" ping on load

// ------------ Utilities ------------
// Correct JSON escaper: don't assign StringReplace's return (it is an int).
string JsonEscape(const string src)
{
   string s = src;
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\r", "\\r");
   StringReplace(s, "\n", "\\n");
   StringReplace(s, "\t", "\\t");
   return s;
}

int ParseHttpStatus(const string hdrs)
{
   int p = StringFind(hdrs, "HTTP/", 0);
   if(p < 0) return 0;
   int sp = StringFind(hdrs, " ", p);
   if(sp < 0) return 0;
   return (int)StringToInteger(StringSubstr(hdrs, sp + 1, 3));
}

// ------------ Discord POST ------------
bool SendDiscord(const string webhook_url,
                 const string content,
                 const string username = "",
                 const string avatar_url = "")
{
   if(StringLen(webhook_url) < 10){
      Print("SendDiscord: webhook URL looks empty/short.");
      return false;
   }

   // Minimal JSON payload (with optional username/avatar)
   string json = "{\"content\":\"" + JsonEscape(content) + "\"";
   if(username   != "") json += ",\"username\":\""   + JsonEscape(username)   + "\"";
   if(avatar_url != "") json += ",\"avatar_url\":\"" + JsonEscape(avatar_url) + "\"";
   json += "}";

   string headers = "Content-Type: application/json\r\n";

   // Convert to UTF-8 and remove trailing NUL byte (Discord rejects NUL)
   char data[];
   int n = StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(n > 0 && data[n - 1] == 0) ArrayResize(data, n - 1);

   char result[];
   string result_headers = "";

   ResetLastError();
   int bytes = WebRequest("POST", webhook_url, headers, InpHttpTimeoutMs, data, result, result_headers);
   if(bytes == -1){
      PrintFormat("SendDiscord: WebRequest failed, GetLastError=%d (whitelist https://discord.com in Tools > Options > Expert Advisors).",
                  GetLastError());
      return false;
   }

   int status = ParseHttpStatus(result_headers);
   // Some webhooks return 204 with empty body; if headers weren't parsed but no error, assume success
   if(status == 0 && GetLastError() == 0 && bytes >= 0) status = 204;

   string body = CharArrayToString(result, 0, ArraySize(result), CP_UTF8);
   PrintFormat("SendDiscord: HTTP %d, body: %s", status, body);

   return (status >= 200 && status < 300);
}

// ------------ Message builder ------------
string BuildMessageFromDeal(const long   deal_ticket,
                            const string symbol,
                            const ENUM_DEAL_ENTRY entry,
                            const ENUM_DEAL_TYPE  deal_type,
                            const double volume,
                            const double price,
                            const double sl,
                            const double tp,
                            const long   magic,
                            const string comment)
{
   string side = (deal_type == DEAL_TYPE_BUY)  ? "BUY" :
                 (deal_type == DEAL_TYPE_SELL) ? "SELL" : "N/A";

   string action = "Trade";
   if(entry == DEAL_ENTRY_IN)         action = "Opened";
   else if(entry == DEAL_ENTRY_OUT)   action = "Closed";
   else if(entry == DEAL_ENTRY_INOUT) action = "Reversed";
   else if(entry == DEAL_ENTRY_OUT_BY)action = "Closed By";
   else if(entry == DEAL_ENTRY_STATE) action = "Modified";

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   string msg;
   msg = action + " " + side + " " + symbol
       + " " + DoubleToString(volume, 2) + " lots"
       + " @ " + DoubleToString(price, digits);

   if(InpIncludeSLTP){
      if(sl > 0) msg += " | SL: " + DoubleToString(sl, digits);
      if(tp > 0) msg += " | TP: " + DoubleToString(tp, digits);
   }

   if(comment != "") msg += "\nComment: " + comment;
   if(InpIncludeMagic && magic != 0) msg += "\nMagic: " + (string)magic;

   if(InpIncludeAccount){
      long   login  = AccountInfoInteger(ACCOUNT_LOGIN);
      string broker = AccountInfoString(ACCOUNT_COMPANY);
      string cur    = AccountInfoString(ACCOUNT_CURRENCY);
      double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
      msg += StringFormat("\nAccount: %I64d (%s) | Bal: %.2f %s | Eq: %.2f %s",
                          login, broker, bal, cur, eq, cur);
   }

   msg += StringFormat("\nTicket: %I64d | Time: %s",
                       deal_ticket, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   return msg;
}

// ------------ Helpers ------------
bool GetPositionSLTP(const string sym, double &sl, double &tp, long &magic)
{
   if(!PositionSelect(sym)) return false;
   sl    = PositionGetDouble(POSITION_SL);
   tp    = PositionGetDouble(POSITION_TP);
   magic = (long)PositionGetInteger(POSITION_MAGIC);
   return true;
}

// ------------ EA lifecycle ------------
int OnInit()
{
   Print("DiscordNotifier initialized.");
   if(InpSendStartupPing){
      string who = AccountInfoString(ACCOUNT_COMPANY);
      long   id  = AccountInfoInteger(ACCOUNT_LOGIN);
      SendDiscord(InpWebhookURL,
                  StringFormat("Bot online on %I64d (%s) @ %s",
                               id, who, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)),
                  InpBotName, InpAvatarURL);
   }
   return(INIT_SUCCEEDED);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD && trans.type != TRADE_TRANSACTION_ORDER_UPDATE)
      return;

   // New execution (open/close/partial)
   if(trans.deal > 0 && (InpNotifyOpen || InpNotifyClose))
   {
      if(!HistoryDealSelect(trans.deal)) return;

      string  sym   = (string)HistoryDealGetString(trans.deal, DEAL_SYMBOL);
      long    tk    = trans.deal;
      double  vol   = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
      double  price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
      long    magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      string  comm  = (string)HistoryDealGetString(trans.deal, DEAL_COMMENT);
      ENUM_DEAL_TYPE  deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
      ENUM_DEAL_ENTRY entry     = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

      bool isOpen  = (entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT);
      bool isClose = (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY);
      if( (isOpen && !InpNotifyOpen) || (isClose && !InpNotifyClose) )
         return;

      double sl=0.0, tp=0.0; long pos_magic=0;
      GetPositionSLTP(sym, sl, tp, pos_magic);

      string msg = BuildMessageFromDeal(tk, sym, entry, deal_type, vol, price, sl, tp, magic, comm);
      SendDiscord(InpWebhookURL, msg, InpBotName, InpAvatarURL);
      return;
   }

   // SL/TP modifications (optional)
   if(trans.type == TRADE_TRANSACTION_ORDER_UPDATE && InpNotifyModify)
   {
      string sym = trans.symbol;
      if(sym == "" || !PositionSelect(sym)) return;

      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long   magic = (long)PositionGetInteger(POSITION_MAGIC);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      int    digits= (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      string msg = StringFormat("Modified %s position | Vol: %.2f | Open: %.*f",
                                sym, vol, digits, price);
      if(InpIncludeSLTP){
         if(sl > 0) msg += " | SL: " + DoubleToString(sl, digits);
         if(tp > 0) msg += " | TP: " + DoubleToString(tp, digits);
      }
      if(InpIncludeMagic && magic != 0)
         msg += "\nMagic: " + (string)magic;

      SendDiscord(InpWebhookURL, msg, InpBotName, InpAvatarURL);
   }
}
