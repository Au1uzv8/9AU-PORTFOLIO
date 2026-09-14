//+------------------------------------------------------------------+
//|         9AU_NASDAQ100_TREND_M5_CAP300_V4_0.mq5                   |
//|  James Consultant | v1.4 Core + House Money + Kill Switch       |
//|  Magic 919294 | Soft Stop 20% | Hard Kill 25% | Daily 4.5%     |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "4.0"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| INPUTS — v1.4 ทุกตัวครบ + เพิ่ม Step H ใหม่                   |
//+------------------------------------------------------------------+
input int    InpMagicNumber      = 919294;

input group "=== Step A: Filter ==="
input int              InpTrendEMA       = 200;
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_H1;
input int              InpRSIPeriod      = 14;
input double           InpRSIUpperLevel  = 58.0;
input double           InpRSILowerLevel  = 48.0;
input double           InpRSIBuyZoneHigh = 55.0;

input group "=== Silver RSI Pro Filter ==="
input int    InpRSIPeriodH1      = 14;
input double InpRSILowerLevelH1  = 50.0;
input double InpRSIUpperLevelH1  = 64.0;
input bool   InpUseDualTF        = true;

input group "=== Trend Strength (ADX) ==="
input int    InpADXPeriod        = 14;
input double InpADXMin           = 20.0;

input group "=== Step B: Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 5.5;
input double InpInitialLot         = 0.1;
input double InpBaseMultiplier     = 1.12;
input double InpReductionStep      = 0.03;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 4;

input group "=== Step C: Profit & Exit ==="
input double InpBasketTP           = 34.0;
input double InpBasketCutLoss      = 30.0;
input double InpMaxGridDepthATR    = 6.0;
input bool   InpEnablePartialClose = true;
input double InpPartialCloseLevel  = 0.70;
input double InpHardSLMultiplier   = 8.0;
input int    InpMinHoldBars        = 20;

input group "=== Step D: News Filter ==="
input bool   EnableNewsFilter      = true;
input int    NewsBeforeMinutes     = 60;
input int    NewsAfterMinutes      = 60;
input bool   NewsHighImpactOnly    = true;

input group "=== Step E: Safety & Protection ==="
input bool   InpEnableEquityStop   = true;
input double InpSoftStopPercent    = 20.0;   // ★ Soft Stop — CloseAll หยุด trade
input double InpKillSwitchPercent  = 25.0;   // ★ Hard Kill — CloseAll + ExpertRemove
input double InpTrailStartUSD      = 18.0;
input double InpTrailStepATR       = 1.8;
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 0.02;
input double InpMaxSpreadBase      = 210.0;
input double InpMaxSpreadHighVol   = 290.0;
input double InpMaxExposurePercent = 20000.0;
input double InpMinMarginLevel     = 700.0;

input group "=== Step F: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 8;
input int    TradingEndHour        = 23;
input bool   StopFridayAfterClose  = true;
input int    FridayCloseHour       = 18;

input group "=== Step G: Daily Loss Limit ==="
input bool   EnableDailyLossLimit  = true;
input double MaxDailyLossPercent   = 4.5;    // ★ ปรับจาก 3.0 → 4.5

input group "=== Step H: House Money & Compound ==="
input double InpBaseBalance        = 300.0;
input double InpHouseMoneyMult     = 2.0;    // เป้า Balance = Base × mult ($600)
input double InpCompoundStartMult  = 1.5;    // เริ่ม Compound เมื่อ Balance >= $450
input bool   InpEnableCompound     = true;
input double InpCompoundRiskPct    = 2.0;    // % equity per trade
input double InpCompoundCapMult    = 3.0;    // cap lot ไม่เกิน Initial × 3
input int    InpBlinkIntervalSec   = 1;

input group "=== Step I: Telegram ==="
input bool   InpEnableTelegram     = true;
input string InpToken              = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID             = "8053031320";
input double InpTelegramDDAlert    = 15.0;

//+------------------------------------------------------------------+
//| GLOBALS — v1.4 เดิมทุกตัว + House Money state                  |
//+------------------------------------------------------------------+
struct BasketInfo {
   int      buyCount;
   double   totalProfit;
   double   totalLots;
   double   lastBuyPrice;
   double   lastBuyLot;
   double   oldestBuyPrice;
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

// ★ House Money globals
bool     g_houseSent     = false;
bool     g_houseActive   = false;
datetime g_lastBlink     = 0;
bool     g_blinkState    = false;
string   g_labelName     = "9AU_HM_Label";

int      g_handleRSI_H1  = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| TELEGRAM                                                         |
//+------------------------------------------------------------------+
void TelegramSend(string message) {
   if(!InpEnableTelegram) return;
   string url     = "https://api.telegram.org/bot" + InpToken + "/sendMessage";
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   string body    = "chat_id=" + InpChatID + "&text=" + message;
   char req[], res[]; string resHeaders;
   StringToCharArray(body, req, 0, StringLen(body));
   int code = WebRequest("POST", url, headers, 5000, req, res, resHeaders);
   if(code != 200)
      Print("[TELEGRAM] Failed HTTP=", code, " Err=", GetLastError());
}

//+------------------------------------------------------------------+
//| DD ALERT — เหมือน v1.4                                          |
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
   TelegramSend("9AU_NASDAQ100 DD ALERT " + DoubleToString(dd,2)
               + "% | Balance " + DoubleToString(balance,2)
               + " | Equity " + DoubleToString(equity,2)
               + " | " + _Symbol + " " + TimeToString(now,TIME_DATE|TIME_MINUTES));
   ddAlertSent     = true;
   lastDDAlertTime = now;
}

//+------------------------------------------------------------------+
//| ★ HOUSE MONEY — ใหม่                                            |
//+------------------------------------------------------------------+
void CheckHouseMoney() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double target  = InpBaseBalance * InpHouseMoneyMult;

   if(balance < target) {
      if(ObjectFind(0, g_labelName) >= 0) ObjectDelete(0, g_labelName);
      g_houseSent   = false;
      g_houseActive = false;
      return;
   }
   g_houseActive = true;

   // ส่ง Telegram ครั้งเดียว
   if(!g_houseSent) {
      TelegramSend("HOUSE MONEY ALERT 9AU_NASDAQ100"
                  + " | Balance=" + DoubleToString(balance,2)
                  + " | Target $" + DoubleToString(target,0) + " REACHED!"
                  + " | ACTION: Withdraw $" + DoubleToString(InpBaseBalance,0)
                  + " & Reset EA | OR Enable Compound"
                  + " | " + _Symbol + " "
                  + TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES));
      g_houseSent = true;
      Print("[HOUSE MONEY] Target $", DoubleToString(target,0), " reached!");
   }

   // Blink label
   datetime now = TimeCurrent();
   if(now - g_lastBlink >= InpBlinkIntervalSec) {
      g_lastBlink  = now;
      g_blinkState = !g_blinkState;
      if(ObjectFind(0, g_labelName) < 0)
         ObjectCreate(0, g_labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_labelName, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetInteger(0, g_labelName, OBJPROP_XDISTANCE,  20);
      ObjectSetInteger(0, g_labelName, OBJPROP_YDISTANCE,  50);
      ObjectSetInteger(0, g_labelName, OBJPROP_FONTSIZE,   14);
      ObjectSetInteger(0, g_labelName, OBJPROP_BACK,       false);
      ObjectSetInteger(0, g_labelName, OBJPROP_SELECTABLE, false);
      ObjectSetString (0, g_labelName, OBJPROP_TEXT,
                       g_blinkState
                       ? "WITHDRAW $" + DoubleToString(InpBaseBalance,0)
                         + " | Bal=" + DoubleToString(balance,2)
                         + " | House Money Active!"
                       : "");
      ObjectSetInteger(0, g_labelName, OBJPROP_COLOR, clrYellow);
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| ★ COMPOUND LOT — ใหม่                                           |
//+------------------------------------------------------------------+
double GetSniperLot() {
   // ใช้ Compound เฉพาะเมื่อ House Money active และ balance ถึง threshold
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   bool useCompound = InpEnableCompound
                      && g_houseActive
                      && bal >= InpBaseBalance * InpCompoundStartMult;
   if(!useCompound) return InpInitialLot;

   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double capLot = NormalizeDouble(InpInitialLot * InpCompoundCapMult, 2);
   // lot สัดส่วน equity × risk% / InitialLot (เทียบกับ risk ของ InitialLot)
   double riskAmt = eq * InpCompoundRiskPct / 100.0;
   double lot     = NormalizeDouble(riskAmt / (InpBaseBalance * 0.04) * InpInitialLot, 2);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, MathMin(maxLot, capLot));
   return lot;
}

//+------------------------------------------------------------------+
//| ON INIT — v1.4 เดิม + log ใหม่                                 |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);

   if(InpUseDualTF) {
      g_handleRSI_H1 = iRSI(_Symbol, PERIOD_H1, InpRSIPeriodH1, PRICE_CLOSE);
      if(g_handleRSI_H1 == INVALID_HANDLE) {
         Print("ERROR: Failed to create H1 RSI handle");
         return INIT_FAILED;
      }
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("=== 9AU_NASDAQ100 v4.0 | Magic=", InpMagicNumber,
         " | Soft=", InpSoftStopPercent, "% Kill=", InpKillSwitchPercent,
         "% | HM Target=$", InpBaseBalance * InpHouseMoneyMult, " ===");
   TelegramSend("9AU_NASDAQ100 v4.0 Started | " + _Symbol
               + " | Balance=" + DoubleToString(balance,2)
               + " | HM Target=$" + DoubleToString(InpBaseBalance*InpHouseMoneyMult,0)
               + " | Soft=" + DoubleToString(InpSoftStopPercent,0)
               + "% Kill=" + DoubleToString(InpKillSwitchPercent,0) + "%");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| ON DEINIT                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(g_handleRSI_H1 != INVALID_HANDLE) IndicatorRelease(g_handleRSI_H1);
   if(ObjectFind(0, g_labelName) >= 0) ObjectDelete(0, g_labelName);
   Print("=== 9AU_NASDAQ100 v4.0 Stopped. Reason=", reason, " ===");
   TelegramSend("9AU_NASDAQ100 v4.0 Stopped | Reason=" + IntegerToString(reason)
               + " | Balance=" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
}

//+------------------------------------------------------------------+
//| FUNCTIONS — v1.4 ทุกตัว ไม่แตะ                                 |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed() {
   if(!EnableTimeFilter) return true;
   MqlDateTime dt;
   TimeLocal(dt);
   int hour = dt.hour;
   int dow  = dt.day_of_week;
   if(dow >= 1 && dow <= 4) {
      if(hour >= TradingStartHour || hour < TradingEndHour) return true;
   } else if(dow == 5) {
      if(StopFridayAfterClose) {
         if(hour >= TradingStartHour && hour < FridayCloseHour) return true;
      } else {
         if(hour >= TradingStartHour || hour < TradingEndHour) return true;
      }
   }
   return false;
}

bool IsNewBar() {
   static datetime lastBarTime = 0;
   datetime current = iTime(_Symbol, PERIOD_M5, 0);
   if(current != lastBarTime) { lastBarTime = current; return true; }
   return false;
}

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

bool IsDailyLossExceeded() {
   if(!EnableDailyLossLimit) return false;
   double limit = AccountInfoDouble(ACCOUNT_BALANCE) * MaxDailyLossPercent / 100.0;
   return (dailyLoss >= limit);
}

void UpdateBasketInfo() {
   basket.buyCount       = 0;
   basket.totalProfit    = 0;
   basket.totalLots      = 0;
   basket.lastBuyPrice   = 0;
   basket.lastBuyLot     = 0;
   basket.oldestBuyPrice = 0;
   basket.oldestOpenTime = TimeCurrent() + 86400*365;
   datetime oldest       = TimeCurrent() + 86400*365;

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_BUY) continue;

      double   lot    = PositionGetDouble(POSITION_VOLUME);
      double   price  = PositionGetDouble(POSITION_PRICE_OPEN);
      double   profit = PositionGetDouble(POSITION_PROFIT)
                      + PositionGetDouble(POSITION_SWAP);
      datetime otime  = (datetime)PositionGetInteger(POSITION_TIME);

      basket.buyCount++;
      basket.totalProfit += profit;
      basket.totalLots   += lot;
      basket.lastBuyLot   = lot;
      basket.lastBuyPrice = price;
      if(otime < oldest) {
         oldest                = otime;
         basket.oldestBuyPrice = price;
      }
   }
   basket.oldestOpenTime = (basket.buyCount > 0) ? oldest : 0;
}

double GetFirstBuyPrice() { return basket.oldestBuyPrice; }

bool IsBuySignal() {
   double rsiM5 = 0, rsiH1 = 0;
   double buffer[];
   ArrayResize(buffer, 2);
   ArraySetAsSeries(buffer, true);

   int hM5 = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   if(hM5 == INVALID_HANDLE) return false;
   if(CopyBuffer(hM5, 0, 0, 2, buffer) < 2) { IndicatorRelease(hM5); return false; }
   rsiM5 = buffer[0];
   IndicatorRelease(hM5);

   if(g_handleRSI_H1 != INVALID_HANDLE) {
      if(CopyBuffer(g_handleRSI_H1, 0, 0, 2, buffer) < 2) return false;
      rsiH1 = buffer[0];
   }

   bool m5Buy = (rsiM5 >= InpRSILowerLevel && rsiM5 <= InpRSIBuyZoneHigh);
   bool h1Buy = (!InpUseDualTF || rsiH1 < InpRSILowerLevelH1);
   return (m5Buy && h1Buy);
}

bool IsEMARising() {
   double ema0[1], ema5[1];
   int h = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return false;
   if(CopyBuffer(h, 0, 0, 1, ema0) < 1) { IndicatorRelease(h); return false; }
   if(CopyBuffer(h, 0, 5, 1, ema5) < 1) { IndicatorRelease(h); return false; }
   IndicatorRelease(h);
   return (ema0[0] > ema5[0]);
}

double GetADX() {
   double buf[1];
   int h = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   if(h == INVALID_HANDLE) return 0;
   double v = (CopyBuffer(h, 0, 0, 1, buf) > 0) ? buf[0] : 0;
   IndicatorRelease(h);
   return v;
}

double GetATR() {
   double buf[1];
   int h = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(h == INVALID_HANDLE) return 0;
   double v = (CopyBuffer(h, 0, 0, 1, buf) > 0) ? buf[0] : 0;
   IndicatorRelease(h);
   return v;
}

double GetEMAValue() {
   double buf[1];
   int h = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0;
   double v = (CopyBuffer(h, 0, 0, 1, buf) > 0) ? buf[0] : 0;
   IndicatorRelease(h);
   return v;
}

bool IsMinHoldPassed(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return true;
   datetime openTime   = (datetime)PositionGetInteger(POSITION_TIME);
   int      barsPassed = Bars(_Symbol, PERIOD_M5, openTime, TimeCurrent());
   return (barsPassed >= InpMinHoldBars);
}

double CalculateSmartLot(int count, double lastLot) {
   double m    = InpBaseMultiplier - (count * InpReductionStep);
   if(m < InpMinMultiplier) m = InpMinMultiplier;
   double lot  = NormalizeDouble(lastLot * m, 2);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, step);
   lot = MathMin(lot, maxL);
   return lot;
}

bool IsExposureSafe() {
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel > 0 && marginLevel < InpMinMarginLevel) return false;
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxExpose = balance * InpMaxExposurePercent / 100.0;
   double cSize     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double exposure  = basket.totalLots * cSize * bid;
   if(exposure > maxExpose && basket.buyCount > 0) return false;
   return true;
}

void SetHardSL(ulong ticket, double atr) {
   if(!PositionSelectByTicket(ticket)) return;
   double curSL  = PositionGetDouble(POSITION_SL);
   double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
   double newSL  = NormalizeDouble(openPx - atr * InpHardSLMultiplier, _Digits);
   if(curSL == 0 || newSL > curSL) trade.PositionModify(ticket, newSL, 0);
}

void ApplyHardSLAll(double atr) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_BUY) continue;
      if(PositionGetDouble(POSITION_SL) == 0) SetHardSL(t, atr);
   }
}

void CloseAll(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      trade.PositionClose(t);
   }
   Print("=== CLOSE ALL: ", reason, " ===");
   TelegramSend("9AU_NASDAQ100 CLOSE ALL | " + reason
               + " | Balance=" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)
               + " | " + _Symbol);
}

void PartialCloseBasket() {
   if(!InpEnablePartialClose || partialDone) return;
   if(basket.totalProfit < InpBasketTP * InpPartialCloseLevel) return;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_BUY) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol    = PositionGetDouble(POSITION_VOLUME);
      double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half   = NormalizeDouble(vol * 0.5, 2);
      if(step > 0) half = MathRound(half / step) * step;
      if(half >= minLot) trade.PositionClosePartial(t, half);
   }
   partialDone = true;
   Print("[PARTIAL] Done at ", DoubleToString(InpPartialCloseLevel*100,0), "%");
}

void UpdateNewsCalendar() {
   datetime from = TimeCurrent(), to = from + 86400*3;
   ArrayFree(TodayEvents);
   CalendarValueHistory(TodayEvents, from, to);
   lastNewsUpdate = TimeCurrent();
}

bool IsNewsWindowActive() {
   if(!EnableNewsFilter) return false;
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(TodayEvents); i++) {
      MqlCalendarEvent ev; MqlCalendarCountry cntry;
      if(!CalendarEventById(TodayEvents[i].event_id, ev)) continue;
      if(!CalendarCountryById(ev.country_id, cntry)) continue;
      if(cntry.currency != "USD") continue;
      if(NewsHighImpactOnly && ev.importance < 3) continue;
      datetime et = TodayEvents[i].time;
      if(now >= et - NewsBeforeMinutes*60 && now <= et + NewsAfterMinutes*60) return true;
   }
   return false;
}

void TrailBasket(double atr) {
   if(basket.totalProfit < InpTrailStartUSD) return;
   double trailDist = atr * InpTrailStepATR;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_BUY) continue;
      if(!IsMinHoldPassed(t)) continue;
      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = NormalizeDouble(bid - trailDist, _Digits);
      if(newSL > curSL) trade.PositionModify(t, newSL, 0);
   }
}

void CheckTimeExit() {
   if(basket.oldestOpenTime == 0) return;
   if(TimeCurrent() - basket.oldestOpenTime > InpMaxHoldDays * 86400)
      CloseAll("Time Exit: MaxHoldDays exceeded");
}

//+------------------------------------------------------------------+
//| ★ EQUITY STOP — แยก Soft Stop / Hard Kill Switch               |
//+------------------------------------------------------------------+
bool CheckEquityStop() {
   if(!InpEnableEquityStop) return false;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return false;
   double dd = (balance - equity) / balance * 100.0;

   // Hard Kill Switch — CloseAll + ExpertRemove
   if(dd >= InpKillSwitchPercent) {
      CloseAll("KILL SWITCH DD=" + DoubleToString(dd,2) + "%");
      TelegramSend("9AU_NASDAQ100 KILL SWITCH TRIGGERED | DD="
                  + DoubleToString(dd,2) + "% >= "
                  + DoubleToString(InpKillSwitchPercent,0)
                  + "% | EA REMOVED | Balance=" + DoubleToString(balance,2));
      ExpertRemove();
      return true;
   }
   // Soft Stop — CloseAll เท่านั้น ไม่ Remove
   if(dd >= InpSoftStopPercent) {
      Print("[SOFT STOP] DD=", DoubleToString(dd,2), "% >= ", InpSoftStopPercent, "%");
      CloseAll("Soft Stop DD=" + DoubleToString(dd,2) + "%");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ON TICK — v1.4 structure ทุกอย่าง + 3 features ใหม่            |
//+------------------------------------------------------------------+
void OnTick() {

   if(CheckEquityStop()) return;  // ★ Dual-level Kill Switch
   UpdateDailyLoss();
   CheckDDAlert();
   CheckHouseMoney();             // ★ House Money + Blink Label

   UpdateBasketInfo();

   // Basket Cut Loss
   if(basket.buyCount > 0 && basket.totalProfit <= -InpBasketCutLoss) {
      CloseAll("Basket Cut Loss $" + DoubleToString(InpBasketCutLoss,2));
      partialDone = false;
      return;
   }

   // Grid Depth Limiter
   if(basket.buyCount > 0) {
      double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double firstPrice = GetFirstBuyPrice();
      if(firstPrice > 0) {
         double atrVal = GetATR();
         if(atrVal > 0) {
            double depthATR = (firstPrice - bid) / atrVal;
            if(depthATR >= InpMaxGridDepthATR) {
               CloseAll("Grid Depth " + DoubleToString(depthATR,1) + "x ATR");
               partialDone = false;
               return;
            }
         }
      }
   }

   if(!IsNewBar()) return;

   if(EnableTimeFilter && !IsTradingTimeAllowed()) return;
   if(EnableNewsFilter && TimeCurrent() - lastNewsUpdate > 3600) UpdateNewsCalendar();
   if(IsNewsWindowActive()) return;

   double atrVal = GetATR();
   if(atrVal < InpMinATRThreshold) return;

   long   spreadPts      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double maxSpreadAllow = (atrVal > 100) ? InpMaxSpreadHighVol : InpMaxSpreadBase;
   if(spreadPts > maxSpreadAllow) return;

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

   // Sniper Buy
   if(basket.buyCount == 0) {
      if(IsDailyLossExceeded()) return;
      double adxVal = GetADX();
      if(adxVal < InpADXMin) return;
      if(!IsBuySignal()) return;
      if(InpTrendEMA > 0) {
         double emaVal   = GetEMAValue();
         double priceVal = iClose(_Symbol, PERIOD_CURRENT, 1);
         if(priceVal <= emaVal || !IsEMARising()) return;
      }
      if(!IsExposureSafe()) return;

      double lot = GetSniperLot();  // ★ Compound Selective
      if(step > 0) lot = MathRound(lot / step) * step;
      lot = MathMax(lot, minLot);

      if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_NDAQ100 Sniper")) {
         Print("[OPEN] Sniper Lot=", DoubleToString(lot,2),
               " ATR=", DoubleToString(atrVal,2),
               " Compound=", g_houseActive ? "ON" : "OFF");
         ulong ticket = trade.ResultOrder();
         if(ticket > 0) SetHardSL(ticket, atrVal);
      } else {
         Print("[FAIL] Sniper Err=", GetLastError());
      }
   }
   // Grid Buy
   else if(basket.buyCount < InpMaxOrders) {
      if(IsDailyLossExceeded()) return;
      if(ask < basket.lastBuyPrice - dynamicDist) {
         if(!IsExposureSafe()) return;
         double lot = CalculateSmartLot(basket.buyCount, basket.lastBuyLot);
         if(step > 0) lot = MathRound(lot / step) * step;
         lot = MathMax(lot, minLot);
         if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_NDAQ100 Grid")) {
            Print("[OPEN] Grid #", basket.buyCount+1,
                  " Lot=", DoubleToString(lot,2));
            ulong ticket = trade.ResultOrder();
            if(ticket > 0) SetHardSL(ticket, atrVal);
         } else {
            Print("[FAIL] Grid Err=", GetLastError());
         }
      }
   }
}
//+------------------------------------------------------------------+
