//+------------------------------------------------------------------+
//|      9AU_Platinum_TREND_M5_CAP300_v1_5.mq5                            |
//|      James Consultant | House Money + Dynamic Lot + Withdraw     |
//|      Magic 919292 | DD<20% | WinRate>70% | PF>1.50               |
//|      v1.5 – House Money Label, Dynamic Lot, Withdraw & Reset     |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "1.5"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input int    InpMagicNumber      = 919292;

input group "=== Step A: Filter ==="
input int              InpTrendEMA       = 0;
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_M30;
input int              InpRSIPeriod      = 14;
input double           InpRSIUpperLevel  = 75.0;
input double           InpRSILowerLevel  = 25.0;

input group "=== Silver RSI Pro Filter ==="
input int    InpRSIPeriodH1      = 14;
input double InpRSILowerLevelH1  = 40.0;
input double InpRSIUpperLevelH1  = 60.0;
input bool   InpUseDualTF        = true;

input group "=== Step B: Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 4.5;
input double InpInitialLot         = 0.02;
input double InpBaseMultiplier     = 1.25;
input double InpReductionStep      = 0.03;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 5;
// ★★★ Module 2: Dynamic Lot Compound ★★★
input bool   InpUseDynamicLot      = false;    // เปิดใช้ Compound Lot (Dynamic)
input double InpRiskPercent        = 1.0;      // % ความเสี่ยงต่อ Trade (เมื่อเปิด Dynamic)

input group "=== Step C: Profit & Exit ==="
input double InpBasketTP           = 18.0;
input bool   InpEnablePartialClose = false;
input double InpPartialCloseLevel  = 0.50;
input double InpHardSLMultiplier   = 9.0;
input int    InpMinHoldBars        = 12;

input group "=== Step D: News Filter ==="
input bool   EnableNewsFilter      = true;
input int    NewsBeforeMinutes     = 60;
input int    NewsAfterMinutes      = 60;
input bool   NewsHighImpactOnly    = true;

input group "=== Step E: Safety & Protection ==="
input bool   InpEnableEquityStop   = true;
input double InpMaxDrawdownPercent = 30.0;
input double InpTrailStartUSD      = 8.0;
input double InpTrailStepATR       = 2.0;
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 0.02;
input double InpMaxSpreadBase      = 450.0;
input double InpMaxSpreadHighVol   = 500.0;
input double InpMaxExposurePercent = 20.0;
input double InpMinMarginLevel      = 700.0;

input group "=== Step F: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 13;
input int    TradingEndHour        = 23;
input bool   StopFridayAfterClose  = true;
input int    FridayCloseHour       = 18;

input group "=== Step G: Daily Loss Limit ==="
input bool   EnableDailyLossLimit  = true;
input double MaxDailyLossPercent   = 4.5;

input group "=== Step H: Telegram Notify ==="
input bool   InpEnableTelegram     = true;
input string InpToken              = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID             = "8053031320";
input double InpTelegramDDAlert    = 15.0;
input bool   InpEnable2xAlert      = true;
input double InpBaseBalance        = 300.0;

//--- Globals
struct BasketInfo {
   int      buyCount;
   int      sellCount;
   double   totalProfit;
   double   totalLots;
   double   lastBuyPrice;
   double   lastSellPrice;
   double   lastBuyLot;
   double   lastSellLot;
   datetime oldestOpenTime;
};
BasketInfo basket;

datetime lastNewsUpdate  = 0;
MqlCalendarValue TodayEvents[];

datetime currentDay      = 0;
double   dailyLoss       = 0.0;
bool     partialDone     = false;
bool     ddAlertSent     = false;
datetime lastDDAlertTime = 0;
int      last2xLevel     = 1;
// ★★★ Module 1 & 3: Withdraw waiting state ★★★
bool     g_waitingForWithdraw = false;

// Handle memory leak fix (v1.4)
int      g_handleATR      = INVALID_HANDLE;
int      g_handleEMA      = INVALID_HANDLE;
int      g_handleRSI_M5   = INVALID_HANDLE;
int      g_handleRSI_H1   = INVALID_HANDLE;

// Peak Equity & Balance (v1.4)
double   g_peakEquity     = 0.0;
double   g_peakBalance    = 0.0;

//+------------------------------------------------------------------+
void TelegramSend(string message) {
   if(!InpEnableTelegram) return;
   string url     = "https://api.telegram.org/bot" + InpToken + "/sendMessage";
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   string body    = "chat_id=" + InpChatID + "&text=" + message;
   char   req[], res[];
   string resHeaders;
   StringToCharArray(body, req, 0, StringLen(body));
   int code = WebRequest("POST", url, headers, 5000, req, res, resHeaders);
   if(code == 200)
      Print("[TELEGRAM] Sent OK");
   else
      Print("[TELEGRAM] Failed HTTP=", code, " Err=", GetLastError());
}

//+------------------------------------------------------------------+
void CheckDDAlert() {
   if(!InpEnableTelegram) return;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return;
   double dd = (balance - equity) / balance * 100.0;
   if(dd < InpTelegramDDAlert) { ddAlertSent = false; return; }
   datetime now = TimeCurrent();
   if(ddAlertSent && (now - lastDDAlertTime) < 3600) return;
   string msg = "9AU_XPTUSD DD " + DoubleToString(dd, 2)
              + "pct | Balance " + DoubleToString(balance, 2)
              + " | Equity " + DoubleToString(equity, 2)
              + " | " + _Symbol + " " + TimeToString(now, TIME_DATE|TIME_MINUTES);
   TelegramSend(msg);
   ddAlertSent     = true;
   lastDDAlertTime = now;
}

//+------------------------------------------------------------------+
//| Module 1 & 2: House Money Alert Label & Dynamic Lot System       |
//+------------------------------------------------------------------+
void DrawHouseMoneyAlert(bool active, double balance, int cur2x) {
   string lbl = "HouseMoneyAlert";
   if(!active) { ObjectDelete(0, lbl); return; }
   ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 50);
   ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 50);
   
   datetime now = TimeCurrent();
   color c = (now % 2 == 0) ? clrRed : clrYellow; // กระพริบทุก 1 วินาที
   
   string text = "⚠️ HOUSE MONEY ALERT! Balance: " + DoubleToString(balance,2) 
               + " | Please Withdraw: " + DoubleToString(balance - InpBaseBalance, 2);
   ObjectSetString(0, lbl, OBJPROP_TEXT, text);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, c);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

double GetBaseLot(double atrVal) {
   if(!InpUseDynamicLot) return InpInitialLot;
   
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmt = equity * InpRiskPercent / 100.0;
   
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double slDistance = atrVal * InpHardSLMultiplier;
   
   if(tickSz == 0 || tickVal == 0 || slDistance <= 0) return InpInitialLot;
   
   double lot = riskAmt / ((slDistance / tickSz) * tickVal);
   return lot;
}

//+------------------------------------------------------------------+
//| Module 3: Withdraw Detection & Reset EA                          |
//+------------------------------------------------------------------+
void Check2xBalance() {
   if(!InpEnable2xAlert) return;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int    cur2x   = (int)MathFloor(balance / InpBaseBalance);
   
   // ตรวจสอบว่ามีการถอนเงินออกไปแล้วหรือยัง
   if(g_waitingForWithdraw && balance < InpBaseBalance * last2xLevel) {
      Print("[RESET] Withdrawal detected. Resuming EA & Resetting Peak.");
      g_waitingForWithdraw = false;
      DrawHouseMoneyAlert(false, 0, 0); // ปิดป้ายเตือน
      
      // รีเซ็ต Peak ต่ำลงมาหลังถอน
      g_peakBalance = balance;
      g_peakEquity  = equity;
      last2xLevel   = (int)MathFloor(balance / InpBaseBalance);
      if(last2xLevel < 1) last2xLevel = 1;
      return;
   }

   // แสดงป้ายเตือนหากยังไม่ยอมถอน
   if(cur2x <= last2xLevel) {
      if(g_waitingForWithdraw) DrawHouseMoneyAlert(true, balance, last2xLevel);
      return;
   }
   
   // แตะเป้าหมายใหม่ (2x, 3x, ...)
   last2xLevel = cur2x;
   g_waitingForWithdraw = true;
   
   double profit = balance - InpBaseBalance;
   double withdrawAmt = balance - InpBaseBalance;
   
   if(InpEnableTelegram) {
      string msg = "🏆 HOUSE MONEY REACHED! 9AU_XPTUSD"
                 + "\nBalance: " + DoubleToString(balance, 2)
                 + "\nTotal Profit: " + DoubleToString(profit, 2)
                 + "\nSuggested Withdraw: " + DoubleToString(withdrawAmt, 2)
                 + "\nRestart with: $" + DoubleToString(InpBaseBalance, 0);
      TelegramSend(msg);
   }
   DrawHouseMoneyAlert(true, balance, last2xLevel);
}

//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   last2xLevel = (int)MathFloor(balance / InpBaseBalance);
   if(last2xLevel < 1) last2xLevel = 1;

   // Peak start values
   g_peakBalance = balance;
   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);

   double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(InpInitialLot < brokerMinLot) {
      Print("[WARN] InpInitialLot=", InpInitialLot,
            " < BrokerMinLot=", brokerMinLot,
            " -> Lot will be snapped to ", brokerMinLot,
            " -> Grid will flat, no scaling");
   }

   // Create handles (v1.4 fix)
   g_handleATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(g_handleATR == INVALID_HANDLE) return INIT_FAILED;

   g_handleRSI_M5 = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   if(g_handleRSI_M5 == INVALID_HANDLE) return INIT_FAILED;

   if(InpTrendEMA > 0) {
      g_handleEMA = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(g_handleEMA == INVALID_HANDLE) return INIT_FAILED;
   }

   if(InpUseDualTF) {
      g_handleRSI_H1 = iRSI(_Symbol, PERIOD_H1, InpRSIPeriodH1, PRICE_CLOSE);
      if(g_handleRSI_H1 == INVALID_HANDLE) return INIT_FAILED;
   }

   Print("=== 9AU_XPTUSD Loaded v1.5 | Magic=", InpMagicNumber,
         " | Lot=", InpInitialLot,
         " | MaxDD=", InpMaxDrawdownPercent, "%",
         " | DualTF=", InpUseDualTF,
         " | DynamicLot=", InpUseDynamicLot,
         " | BaseBalance=$", InpBaseBalance,
         " | 2xTarget=$", InpBaseBalance*2, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_XPTUSD Started v1.5 | " + _Symbol
                   + " | Balance " + DoubleToString(balance,2)
                   + " | Fixed Lot " + DoubleToString(InpInitialLot,2)
                   + " | DualTF " + (InpUseDualTF ? "ON" : "OFF")
                   + " | 2x Target $" + DoubleToString(InpBaseBalance*2,0));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Release handles
   if(g_handleATR    != INVALID_HANDLE) IndicatorRelease(g_handleATR);
   if(g_handleEMA    != INVALID_HANDLE) IndicatorRelease(g_handleEMA);
   if(g_handleRSI_M5 != INVALID_HANDLE) IndicatorRelease(g_handleRSI_M5);
   if(g_handleRSI_H1 != INVALID_HANDLE) IndicatorRelease(g_handleRSI_H1);

   Print("=== 9AU_XPTUSD Stopped. Reason: ", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_XPTUSD Stopped | Reason " + IntegerToString(reason)
                   + " | Balance " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)
                   + " | " + _Symbol);
}

//+------------------------------------------------------------------+
bool IsTradingTimeAllowed() {
   if(!EnableTimeFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);  // v1.4 fix
   int hour = dt.hour;
   int dow  = dt.day_of_week;
   if(dow >= 1 && dow <= 4) {
      if(hour >= TradingStartHour && hour < TradingEndHour) return true;
   } else if(dow == 5) {
      if(StopFridayAfterClose) {
         if(hour >= TradingStartHour && hour < FridayCloseHour) return true;
      } else {
         if(hour >= TradingStartHour && hour < TradingEndHour) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool IsNewBar() {
   static datetime lastBarTime = 0;
   datetime current = iTime(_Symbol, PERIOD_M5, 0);
   if(current != lastBarTime) { lastBarTime = current; return true; }
   return false;
}

//+------------------------------------------------------------------+
void UpdateDailyLoss() {
   datetime today = TimeCurrent() / 86400 * 86400;
   if(today != currentDay) {
      currentDay  = today;
      dailyLoss   = 0.0;
      partialDone = false;
   }
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
   double loss = bal - eq;
   if(loss > dailyLoss) dailyLoss = loss;
}

//+------------------------------------------------------------------+
bool IsDailyLossExceeded() {
   if(!EnableDailyLossLimit) return false;
   double limit = AccountInfoDouble(ACCOUNT_BALANCE) * MaxDailyLossPercent / 100.0;
   if(dailyLoss >= limit) {
      Print("[SKIP] DailyLoss=", DoubleToString(dailyLoss,2), " / Limit=", DoubleToString(limit,2));
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void UpdateBasketInfo() {
   basket.buyCount       = 0;
   basket.sellCount      = 0;
   basket.totalProfit    = 0;
   basket.totalLots      = 0;
   basket.lastBuyPrice   = 0;
   basket.lastSellPrice  = 0;
   basket.lastBuyLot     = 0;
   basket.lastSellLot    = 0;
   basket.oldestOpenTime = TimeCurrent() + 86400 * 365;
   datetime oldest       = TimeCurrent() + 86400 * 365;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      double   lot      = PositionGetDouble(POSITION_VOLUME);
      double   price    = PositionGetDouble(POSITION_PRICE_OPEN);
      double   profit   = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      basket.totalProfit += profit;
      basket.totalLots   += lot;
      if(openTime < oldest) oldest = openTime;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         basket.buyCount++;
         basket.lastBuyLot   = lot;
         basket.lastBuyPrice = price;
      } else {
         basket.sellCount++;
         basket.lastSellLot   = lot;
         basket.lastSellPrice = price;
      }
   }
   basket.oldestOpenTime = (basket.buyCount + basket.sellCount > 0) ? oldest : 0;
}

//+------------------------------------------------------------------+
bool IsSilverRSISignal(ENUM_ORDER_TYPE type) {
   double rsiM5 = 0, rsiH1 = 0;
   double buffer[];
   ArrayResize(buffer, 2);
   ArraySetAsSeries(buffer, true);

   if(g_handleRSI_M5 == INVALID_HANDLE) return false;
   if(CopyBuffer(g_handleRSI_M5, 0, 0, 2, buffer) < 2) return false;
   rsiM5 = buffer[0];

   if(InpUseDualTF && g_handleRSI_H1 != INVALID_HANDLE) {
      if(CopyBuffer(g_handleRSI_H1, 0, 0, 2, buffer) < 2) return false;
      rsiH1 = buffer[0];
   }

   if(type == ORDER_TYPE_BUY) {
      bool m5Buy = (rsiM5 < InpRSILowerLevel);
      bool h1Buy = (!InpUseDualTF || rsiH1 < InpRSILowerLevelH1);
      return (m5Buy && h1Buy);
   }
   if(type == ORDER_TYPE_SELL) {
      bool m5Sell = (rsiM5 > InpRSIUpperLevel);
      bool h1Sell = (!InpUseDualTF || rsiH1 > InpRSIUpperLevelH1);
      return (m5Sell && h1Sell);
   }
   return false;
}

//+------------------------------------------------------------------+
double GetATR() {
   double buf[1];
   if(CopyBuffer(g_handleATR, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetEMA() {
   if(g_handleEMA == INVALID_HANDLE) return 0.0;
   double buf[1];
   if(CopyBuffer(g_handleEMA, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
bool IsMinHoldPassed(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return true;
   datetime openTime   = (datetime)PositionGetInteger(POSITION_TIME);
   int      barsPassed = Bars(_Symbol, PERIOD_M5, openTime, TimeCurrent());
   return (barsPassed >= InpMinHoldBars);
}

//+------------------------------------------------------------------+
double CalculateSmartLot(int count, double lastLot) {
   double m = InpBaseMultiplier - (count * InpReductionStep);
   if(m < InpMinMultiplier) m = InpMinMultiplier;
   double lot    = NormalizeDouble(lastLot * m, 2);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, step);
   lot = MathMin(lot, maxLot);
   return lot;
}

//+------------------------------------------------------------------+
bool IsExposureSafe() {
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel <= 0) return true;
   if(marginLevel < InpMinMarginLevel) {
      Print("[SKIP] Margin Level too low: ", DoubleToString(marginLevel,2), "% < ", InpMinMarginLevel, "%");
      return false;
   }

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxExpose = balance * InpMaxExposurePercent / 100.0;
   double cSize     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double exposure  = basket.totalLots * cSize * bid;
   if(exposure > maxExpose && basket.buyCount > 0) {
      Print("[SKIP] Exposure=", DoubleToString(exposure,2), " > Max=", DoubleToString(maxExpose,2));
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void SetHardSL(ulong ticket, double atr) {
   if(!PositionSelectByTicket(ticket)) return;
   double curSL  = PositionGetDouble(POSITION_SL);
   double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double slDist = atr * InpHardSLMultiplier;
   double newSL  = 0;
   if(ptype == POSITION_TYPE_BUY) {
      newSL = NormalizeDouble(openPx - slDist, _Digits);
      if(curSL == 0 || newSL > curSL) trade.PositionModify(ticket, newSL, 0);
   } else {
      newSL = NormalizeDouble(openPx + slDist, _Digits);
      if(curSL == 0 || newSL < curSL) trade.PositionModify(ticket, newSL, 0);
   }
}

//+------------------------------------------------------------------+
void ApplyHardSLAll(double atr) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetDouble(POSITION_SL) == 0) SetHardSL(t, atr);
   }
}

//+------------------------------------------------------------------+
void CloseAll(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      trade.PositionClose(t);
   }
   Print("=== CLOSE ALL: ", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_XPTUSD CLOSE ALL | " + reason
                   + " | Balance " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)
                   + " | " + _Symbol);
}

//+------------------------------------------------------------------+
void PartialCloseBasket() {
   if(!InpEnablePartialClose || partialDone) return;
   if(basket.totalProfit < InpBasketTP * InpPartialCloseLevel) return;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol    = PositionGetDouble(POSITION_VOLUME);
      double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half   = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / step) * step;
      if(half >= minLot) {
         trade.PositionClosePartial(t, half);
         Print("[PARTIAL] Ticket=", t, " ClosedLot=", half);
      }
   }
   partialDone = true;
   Print("[PARTIAL] Done at ", DoubleToString(InpPartialCloseLevel*100,0), "%");
}

//+------------------------------------------------------------------+
void UpdateNewsCalendar() {
   datetime from = TimeCurrent();
   datetime to   = from + 86400 * 3;
   ArrayFree(TodayEvents);
   CalendarValueHistory(TodayEvents, from, to);
   lastNewsUpdate = TimeCurrent();
}

bool IsNewsWindowActive() {
   if(!EnableNewsFilter) return false;
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(TodayEvents); i++) {
      MqlCalendarEvent   ev;
      MqlCalendarCountry cntry;
      if(!CalendarEventById(TodayEvents[i].event_id, ev)) continue;
      if(!CalendarCountryById(ev.country_id, cntry)) continue;
      if(cntry.currency != "USD") continue;
      if(NewsHighImpactOnly && ev.importance < 3) continue;
      datetime eventTime = TodayEvents[i].time;
      if(now >= eventTime - NewsBeforeMinutes*60 && now <= eventTime + NewsAfterMinutes*60) {
         Print("[SKIP] News: ", ev.name);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
void TrailBasket(double atr) {
   if(basket.totalProfit < InpTrailStartUSD) return;
   double trailDist = atr * InpTrailStepATR;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsMinHoldPassed(t)) continue;
      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = 0;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         newSL = NormalizeDouble(bid - trailDist, _Digits);
         if(newSL > curSL) trade.PositionModify(t, newSL, 0);
      } else {
         newSL = NormalizeDouble(ask + trailDist, _Digits);
         if(curSL == 0 || newSL < curSL) trade.PositionModify(t, newSL, 0);
      }
   }
}

//+------------------------------------------------------------------+
void CheckTimeExit() {
   if(basket.oldestOpenTime == 0) return;
   if(TimeCurrent() - basket.oldestOpenTime > InpMaxHoldDays * 86400)
      CloseAll("Time Exit: MaxHoldDays exceeded");
}

//+------------------------------------------------------------------+
// Equity Stop based on Peak Equity (v1.4)
bool CheckEquityStop() {
   if(!InpEnableEquityStop) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_peakEquity <= 0) return false;
   double dd = (g_peakEquity - equity) / g_peakEquity * 100.0;
   if(dd >= InpMaxDrawdownPercent) {
      Print("[STOP] PeakEquityDD=", DoubleToString(dd,2), "% >= Limit=", InpMaxDrawdownPercent, "%");
      CloseAll("Equity Stop PeakDD=" + DoubleToString(dd,2) + "%");
      ExpertRemove();
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void OnTick() {
   // Update peak values (v1.4)
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > g_peakEquity) g_peakEquity = currentEquity;
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currentBalance > g_peakBalance) g_peakBalance = currentBalance;

   if(CheckEquityStop()) return;
   UpdateDailyLoss();
   CheckDDAlert();
   Check2xBalance();   // ★ Module 3: Withdraw & Reset
   if(IsDailyLossExceeded()) return;

   if(!IsNewBar()) return;

   if(EnableTimeFilter && !IsTradingTimeAllowed()) return;
   if(EnableNewsFilter && TimeCurrent() - lastNewsUpdate > 3600) UpdateNewsCalendar();
   if(IsNewsWindowActive()) return;

   double atrVal = GetATR();
   if(atrVal < InpMinATRThreshold) {
      Print("[SKIP] ATR=", DoubleToString(atrVal,2), " < Min=", InpMinATRThreshold);
      return;
   }
   long   spreadPts      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double maxSpreadAllow = (atrVal > 100) ? InpMaxSpreadHighVol : InpMaxSpreadBase;
   if(spreadPts > maxSpreadAllow) {
      Print("[SKIP] Spread=", spreadPts, " > Max=", maxSpreadAllow);
      return;
   }

   if(!IsSilverRSISignal(ORDER_TYPE_BUY)) return;

   double priceVal = iClose(_Symbol, PERIOD_CURRENT, 1);
   double emaVal   = GetEMA();
   if(InpTrendEMA > 0 && priceVal <= emaVal) {
      Print("[SKIP] Price=", DoubleToString(priceVal,2), " <= EMA=", DoubleToString(emaVal,2));
      return;
   }

   UpdateBasketInfo();
   CheckTimeExit();
   ApplyHardSLAll(atrVal);

   if(basket.buyCount > 0) {
      TrailBasket(atrVal);
      PartialCloseBasket();
      if(basket.totalProfit >= InpBasketTP) {
         CloseAll("Basket TP=" + DoubleToString(InpBasketTP,2) + " Reached");
         partialDone = false;
         return;
      }
   }

   double dynamicDist = InpEnableDynamicGrid
                        ? MathMax(atrVal * InpATRMultiplier, 300.0 * _Point)
                        : 300.0 * _Point;
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   if(basket.buyCount == 0) {
      // ★ หากเปิดให้รอถอนก่อนเปิดไม้ใหม่ ให้ปลด comment บรรทัดล่าง ★
      // if(g_waitingForWithdraw) return;

      double baseLot = GetBaseLot(atrVal);  // ★ Module 2: Dynamic Lot
      double lot = NormalizeDouble(baseLot, 2);
      if(step > 0) lot = MathRound(lot / step) * step;
      lot = MathMax(lot, minLot);
      if(!IsExposureSafe()) return;
      if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_XPTUSD Sniper")) {
         Print("[OPEN] Sniper Buy Lot=", DoubleToString(lot,2), " ATR=", DoubleToString(atrVal,2));
         ulong ticket = trade.ResultOrder();
         if(ticket > 0) SetHardSL(ticket, atrVal);
      } else {
         Print("[FAIL] Sniper Buy Err=", GetLastError());
      }
   } else if(basket.buyCount < InpMaxOrders) {
      if(ask < basket.lastBuyPrice - dynamicDist) {
         if(!IsExposureSafe()) return;
         double lot = CalculateSmartLot(basket.buyCount, basket.lastBuyLot);
         if(step > 0) lot = MathRound(lot / step) * step;
         lot = MathMax(lot, minLot);
         if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_XPTUSD Grid")) {
            Print("[OPEN] Grid Buy #", basket.buyCount+1, " Lot=", DoubleToString(lot,2));
            ulong ticket = trade.ResultOrder();
            if(ticket > 0) SetHardSL(ticket, atrVal);
         } else {
            Print("[FAIL] Grid Buy Err=", GetLastError());
         }
      }
   }
}
//+------------------------------------------------------------------+