//+------------------------------------------------------------------+
//|         9AU_NDAQ100_COMBINE_M5_CAP300.mq5                        |
//|  James Consultant | Combine Mode — Money & Risk Management Only  |
//|  Magic 919294 | Virtual Equity Isolation | Soft 20% Kill 25%    |
//|  v1.1 Fix G: Virtual Balance/Equity per Magic Number             |
//|  (เดิม v1.0 diff จาก ACCOUNT_EQUITY ทั้งบัญชี ปนกับ EA อื่นที่รัน|
//|  ร่วมบัญชี เช่น GBPJPY 515254 — แก้เป็นกรอง Deal/Position ด้วย   |
//|  InpMagicNumber ของตัวเองเท่านั้น sync pattern เดียวกับ          |
//|  GBPJPY/AUDCAD/OIL/USDJPY Combine)                                |
//|  v1.2: เพิ่ม InpDCAtoAdd (Manual DCA, Cumulative Total) +         |
//|  Global Variable Delta Guard + On-Chart Label                     |
//|  v1.2.1: เพิ่ม Crisis Monitor — แจ้งเตือนสลับเป็น v1.3.4 เมื่อ   |
//|  NDX ลง >InpCrisisDrawdownPct% จาก Rolling ATH (D1 lookback)     |
//|  Alert: Blink on-chart + Telegram — ไม่มี auto-switch             |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "1.21"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| INPUTS                                                           |
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
input double InpSoftStopPercent    = 20.0;
input double InpKillSwitchPercent  = 25.0;
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
input double MaxDailyLossPercent   = 4.5;

input group "=== Step H: House Money & Compound ==="
input double InpBaseBalance        = 300.0;
input double InpHouseMoneyMult     = 2.0;
input double InpCompoundStartMult  = 1.5;
input bool   InpEnableCompound     = true;
input double InpCompoundRiskPct    = 2.0;
input double InpCompoundCapMult    = 3.0;
input int    InpBlinkIntervalSec   = 1;

input group "=== Step I: Telegram ==="
input bool   InpEnableTelegram     = true;
input string InpToken              = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID             = "8053031320";
input double InpTelegramDDAlert    = 15.0;

input group "=== Step J: Combine Mode — Money & Risk Management ==="
input bool   InpCombineMode        = true;   // เปิด Combine Mode
input double InpActiveBase         = 300.0;  // ทุนที่ active ใน EA นี้ (ไม่รวม Reserve) — ใช้เป็น Virtual Base Balance
input double InpCombineDDLimit     = 20.0;   // DD limit คำนวณบน Virtual Equity (%)
input double InpCombineKillSwitch  = 25.0;   // Hard Kill บน Virtual Equity (%)

input group "=== Step K: Manual DCA (Cumulative Total, ไม่ใช่ยอดต่อเดือน) ==="
input double InpDCAtoAdd           = 0.0;    // กรอกเป็นยอด DCA สะสมทั้งหมดตั้งแต่เริ่ม (เดือน1=25, เดือน2=50 ...)

input group "=== Step L: Crisis Monitor (แจ้งเตือนสลับ EA) ==="
input int    InpATHLookbackDays      = 252;   // Rolling ATH lookback (D1 bars) — 252 = 1 ปีทำการ
input double InpCrisisDrawdownPct    = 15.0;  // NDX ลงจาก ATH กี่% → alert สลับเป็น v1.3.4
input int    InpCrisisAlertIntervalMin = 240; // re-alert ทุกกี่นาที (ป้องกัน spam) default=4h

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
// Crisis Monitor globals (v1.2.1)
datetime g_lastCrisisAlertTime = 0;
bool     g_crisisAlertActive   = false;
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

// House Money
bool     g_houseSent     = false;
bool     g_houseActive   = false;
datetime g_lastBlink     = 0;
bool     g_blinkState    = false;
string   g_labelName     = "9AU_HM_Label";

// Combine Mode — Virtual Balance/Equity per Magic Number (Fix G pattern, sync กับ GBPJPY/AUDCAD/OIL/USDJPY)
double   g_vRealizedProfit  = 0.0;   // Realized P/L สะสมเฉพาะ Magic นี้ (จาก Deal History + OnTradeTransaction)

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
//| VIRTUAL BALANCE / EQUITY — per Magic Number (Fix G)               |
//| แก้จาก ACCOUNT_EQUITY diff (ปนกับ EA อื่นในบัญชีเดียวกัน) เป็น     |
//| การกรอง Deal History + Position ด้วย InpMagicNumber ของตัวเองเท่านั้น |
//| sync pattern เดียวกับ GBPJPY/AUDCAD/OIL/USDJPY Combine ทุกตัว      |
//+------------------------------------------------------------------+
void ScanInitialRealizedProfit() {
   g_vRealizedProfit = 0.0;
   if(!HistorySelect(0, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
      g_vRealizedProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) return;
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;
   g_vRealizedProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
}

double GetVirtualBalance() {
   if(!InpCombineMode) return AccountInfoDouble(ACCOUNT_BALANCE);
   return InpActiveBase + g_vRealizedProfit;
}

double GetVirtualEquity() {
   if(!InpCombineMode) return AccountInfoDouble(ACCOUNT_EQUITY);
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return GetVirtualBalance() + floating;
}

//+------------------------------------------------------------------+
//| MANUAL DCA — Cumulative Total + Global Variable Delta Guard        |
//| (Pattern เดียวกับ Gold/OIL-WTI/GBPJPY/USDJPY/AUDCAD/3PAIRS)        |
//+------------------------------------------------------------------+
string GVName_DCA() { return "9AU_DCA_APPLIED_" + IntegerToString(InpMagicNumber); }

void ApplyDCAIfNeeded() {
   string gv = GVName_DCA();
   double lastApplied = GlobalVariableCheck(gv) ? GlobalVariableGet(gv) : 0.0;
   double delta = InpDCAtoAdd - lastApplied;
   if(MathAbs(delta) < 0.01) return;

   g_vRealizedProfit += delta;
   GlobalVariableSet(gv, InpDCAtoAdd);
   Print("[DCA] NDAQ100 Applied Delta=$", DoubleToString(delta,2),
         " | Cumulative Target=$", DoubleToString(InpDCAtoAdd,2),
         " | New VBal=$", DoubleToString(GetVirtualBalance(),2));
   if(InpEnableTelegram)
      TelegramSend("9AU_NDAQ100 DCA APPLIED | Delta=$" + DoubleToString(delta,2)
                   + " | Cumulative=$" + DoubleToString(InpDCAtoAdd,2)
                   + " | New VBal=$" + DoubleToString(GetVirtualBalance(),2));
}

void DrawDCALabel() {
   string name = "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber);
   double applied = GlobalVariableCheck(GVName_DCA()) ? GlobalVariableGet(GVName_DCA()) : 0.0;
   string txt = StringFormat("NDAQ100(%d) DCA Cumulative=$%.2f | VBase=$%.2f | VBal=$%.2f",
                              InpMagicNumber, applied, InpActiveBase, GetVirtualBalance());
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 55);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

//+------------------------------------------------------------------+
//| DD ALERT — ใช้ Virtual Equity ใน Combine Mode                   |
//+------------------------------------------------------------------+
void CheckDDAlert() {
   if(!InpEnableTelegram) return;
   double vBal = GetVirtualBalance();
   double vEq  = GetVirtualEquity();
   if(vBal <= 0) return;
   double dd = (vBal - vEq) / vBal * 100.0;
   if(dd < InpTelegramDDAlert) { ddAlertSent = false; return; }
   datetime now = TimeCurrent();
   if(ddAlertSent && (now - lastDDAlertTime) < 3600) return;
   TelegramSend("9AU_NDAQ100_COMBINE DD ALERT " + DoubleToString(dd,2)
               + "% | VBal=" + DoubleToString(vBal,2)
               + " | VEq=" + DoubleToString(vEq,2)
               + " | " + _Symbol + " " + TimeToString(now,TIME_DATE|TIME_MINUTES));
   ddAlertSent     = true;
   lastDDAlertTime = now;
}

//+------------------------------------------------------------------+
//| HOUSE MONEY                                                      |
//+------------------------------------------------------------------+
void CheckHouseMoney() {
   double vBal   = GetVirtualBalance();
   double vEq    = GetVirtualEquity();
   double target = InpBaseBalance * InpHouseMoneyMult;

   if(vBal < target) {
      if(ObjectFind(0, g_labelName) >= 0) ObjectDelete(0, g_labelName);
      g_houseSent   = false;
      g_houseActive = false;
      return;
   }
   g_houseActive = true;

   if(!g_houseSent) {
      TelegramSend("HOUSE MONEY ALERT 9AU_NDAQ100_COMBINE"
                  + " | VBalance=" + DoubleToString(vBal,2)
                  + " | Target $" + DoubleToString(target,0) + " REACHED!"
                  + " | ACTION: Withdraw $" + DoubleToString(InpBaseBalance,0)
                  + " & Reset EA | OR Enable Compound"
                  + " | " + _Symbol + " "
                  + TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES));
      g_houseSent = true;
   }

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
                         + " | VBal=" + DoubleToString(vBal,2)
                         + " | House Money Active!"
                       : "");
      ObjectSetInteger(0, g_labelName, OBJPROP_COLOR, clrYellow);
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| COMPOUND LOT                                                     |
//+------------------------------------------------------------------+
double GetSniperLot() {
   double vBal = GetVirtualBalance();
   bool useCompound = InpEnableCompound
                      && g_houseActive
                      && vBal >= InpBaseBalance * InpCompoundStartMult;
   if(!useCompound) return InpInitialLot;

   double vEq    = GetVirtualEquity();
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double capLot = NormalizeDouble(InpInitialLot * InpCompoundCapMult, 2);
   double riskAmt= vEq * InpCompoundRiskPct / 100.0;
   double lot    = NormalizeDouble(riskAmt / (InpBaseBalance * 0.04) * InpInitialLot, 2);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, MathMin(maxLot, capLot));
   return lot;
}

//+------------------------------------------------------------------+
//| ON INIT                                                          |
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

   // Combine Mode — กู้คืน Realized P/L สะสมเฉพาะ Magic นี้จาก History (per-Magic isolation)
   ScanInitialRealizedProfit();
   ApplyDCAIfNeeded();
   DrawDCALabel();
   if(InpCombineMode) {
      Print("[COMBINE] RealizedProfit(this Magic)=", DoubleToString(g_vRealizedProfit,2),
            " | ActiveBase=", DoubleToString(InpActiveBase,2));
   }

   double vBal = GetVirtualBalance();
   Print("=== 9AU_NDAQ100_COMBINE v1.2 | Magic=", InpMagicNumber,
         " | CombineMode=", InpCombineMode ? "ON" : "OFF",
         " | VBal=", DoubleToString(vBal,2),
         " | Soft=", InpCombineDDLimit, "% Kill=", InpCombineKillSwitch, "% ===");
   TelegramSend("9AU_NDAQ100_COMBINE v1.2.1 Started | " + _Symbol
               + " | CombineMode=" + (InpCombineMode ? "ON" : "OFF")
               + " | VBal=" + DoubleToString(vBal,2)
               + " | ActiveBase=$" + DoubleToString(InpActiveBase,0)
               + " | HM Target=$" + DoubleToString(InpBaseBalance*InpHouseMoneyMult,0)
               + " | Soft=" + DoubleToString(InpCombineDDLimit,0)
               + "% Kill=" + DoubleToString(InpCombineKillSwitch,0) + "%");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| ON DEINIT                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(g_handleRSI_H1 != INVALID_HANDLE) IndicatorRelease(g_handleRSI_H1);
   if(ObjectFind(0, g_labelName) >= 0) ObjectDelete(0, g_labelName);
   ObjectDelete(0, "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber));
   ObjectDelete(0, "CRISIS_ALERT_LABEL");   // v1.2.1
   Print("=== 9AU_NDAQ100_COMBINE v1.2.1 Stopped. Reason=", reason, " ===");
   TelegramSend("9AU_NDAQ100_COMBINE v1.2.1 Stopped | Reason=" + IntegerToString(reason)
               + " | VBal=" + DoubleToString(GetVirtualBalance(),2));
}

//+------------------------------------------------------------------+
//| FUNCTIONS — v4.0 ทุกตัว                                         |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed() {
   if(!EnableTimeFilter) return true;
   MqlDateTime dt;
   TimeLocal(dt);
   int hour = dt.hour, dow = dt.day_of_week;
   if(dow >= 1 && dow <= 4) return (hour >= TradingStartHour || hour < TradingEndHour);
   if(dow == 5) {
      if(StopFridayAfterClose) return (hour >= TradingStartHour && hour < FridayCloseHour);
      return (hour >= TradingStartHour || hour < TradingEndHour);
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
   double loss = GetVirtualBalance() - GetVirtualEquity();
   if(loss > dailyLoss) dailyLoss = loss;
}

bool IsDailyLossExceeded() {
   if(!EnableDailyLossLimit) return false;
   double limit = GetVirtualBalance() * MaxDailyLossPercent / 100.0;
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
      double   profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime otime  = (datetime)PositionGetInteger(POSITION_TIME);
      basket.buyCount++;
      basket.totalProfit += profit;
      basket.totalLots   += lot;
      basket.lastBuyLot   = lot;
      basket.lastBuyPrice = price;
      if(otime < oldest) { oldest = otime; basket.oldestBuyPrice = price; }
   }
   basket.oldestOpenTime = (basket.buyCount > 0) ? oldest : 0;
}

double GetFirstBuyPrice() { return basket.oldestBuyPrice; }

bool IsBuySignal() {
   double buffer[];
   ArrayResize(buffer, 2);
   ArraySetAsSeries(buffer, true);
   int hM5 = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   if(hM5 == INVALID_HANDLE) return false;
   if(CopyBuffer(hM5, 0, 0, 2, buffer) < 2) { IndicatorRelease(hM5); return false; }
   double rsiM5 = buffer[0];
   IndicatorRelease(hM5);
   if(g_handleRSI_H1 != INVALID_HANDLE) {
      if(CopyBuffer(g_handleRSI_H1, 0, 0, 2, buffer) < 2) return false;
      if(buffer[0] >= InpRSILowerLevelH1) return false;
   }
   return (rsiM5 >= InpRSILowerLevel && rsiM5 <= InpRSIBuyZoneHigh);
}

bool IsEMARising() {
   double ema0[1], ema5[1];
   int h = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return false;
   bool ok = (CopyBuffer(h, 0, 0, 1, ema0) > 0 && CopyBuffer(h, 0, 5, 1, ema5) > 0);
   IndicatorRelease(h);
   return ok ? (ema0[0] > ema5[0]) : false;
}

double GetADX() {
   double buf[1];
   int h = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   if(h == INVALID_HANDLE) return 0;
   double v = (CopyBuffer(h, 0, 0, 1, buf) > 0) ? buf[0] : 0;
   IndicatorRelease(h); return v;
}

double GetATR() {
   double buf[1];
   int h = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(h == INVALID_HANDLE) return 0;
   double v = (CopyBuffer(h, 0, 0, 1, buf) > 0) ? buf[0] : 0;
   IndicatorRelease(h); return v;
}

double GetEMAValue() {
   double buf[1];
   int h = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0;
   double v = (CopyBuffer(h, 0, 0, 1, buf) > 0) ? buf[0] : 0;
   IndicatorRelease(h); return v;
}

bool IsMinHoldPassed(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return true;
   return (Bars(_Symbol, PERIOD_M5, (datetime)PositionGetInteger(POSITION_TIME), TimeCurrent()) >= InpMinHoldBars);
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
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(ml > 0 && ml < InpMinMarginLevel) return false;
   double vBal  = GetVirtualBalance();
   double cSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double exp   = basket.totalLots * cSize * bid;
   if(exp > vBal * InpMaxExposurePercent / 100.0 && basket.buyCount > 0) return false;
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
   TelegramSend("9AU_NDAQ100_COMBINE CLOSE ALL | " + reason
               + " | VBal=" + DoubleToString(GetVirtualBalance(),2)
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
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half = NormalizeDouble(vol * 0.5, 2);
      if(step > 0) half = MathRound(half / step) * step;
      if(half >= minL) trade.PositionClosePartial(t, half);
   }
   partialDone = true;
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
//| CRISIS MONITOR — v1.2.1                                          |
//| คำนวณ Rolling ATH (D1 bars) เปรียบเทียบราคาปัจจุบัน              |
//| ถ้า drawdown >= InpCrisisDrawdownPct% → Blink + Telegram alert   |
//| re-alert ทุก InpCrisisAlertIntervalMin นาที ป้องกัน spam          |
//+------------------------------------------------------------------+
void CheckCrisisMonitor() {
   double hiArr[];
   ArrayResize(hiArr, InpATHLookbackDays);
   int copied = CopyHigh(_Symbol, PERIOD_D1, 0, InpATHLookbackDays, hiArr);
   if(copied < 10) return;   // ข้อมูลไม่พอ

   double rollingATH = hiArr[0];
   for(int i = 1; i < copied; i++)
      if(hiArr[i] > rollingATH) rollingATH = hiArr[i];

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(rollingATH <= 0) return;
   double drawdownPct = (rollingATH - currentPrice) / rollingATH * 100.0;

   bool inCrisis = (drawdownPct >= InpCrisisDrawdownPct);

   // ถ้า crisis หมดแล้ว reset สถานะ
   if(!inCrisis) {
      g_crisisAlertActive = false;
      return;
   }

   // throttle — alert ทุก N นาทีเท่านั้น
   datetime now = TimeCurrent();
   if(g_crisisAlertActive &&
      (now - g_lastCrisisAlertTime) < InpCrisisAlertIntervalMin * 60)
      return;

   // ส่ง alert
   g_crisisAlertActive   = true;
   g_lastCrisisAlertTime = now;

   string msg = "*** CRISIS ALERT *** | NDX ลง " + DoubleToString(drawdownPct,1)
              + "% จาก ATH " + DoubleToString(rollingATH,0)
              + " | Current=" + DoubleToString(currentPrice,0)
              + " | สลับไปใช้ 9AU_NDAQ100_SWAP_CRISIS_M5_CAP300_v1_3_4"
              + " | " + TimeToString(now, TIME_DATE|TIME_MINUTES);

   Print(msg);
   if(InpEnableTelegram) TelegramSend(msg);

   // Blink chart object (กระพริบสีแดง)
   string objName = "CRISIS_ALERT_LABEL";
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, objName, OBJPROP_COLOR,
                    (TimeCurrent() % 2 == 0) ? clrRed : clrYellow);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 16);
   ObjectSetString(0, objName, OBJPROP_TEXT,
                   "CRISIS: NDX -" + DoubleToString(drawdownPct,1)
                   + "% | สลับ -> v1.3.4");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| EQUITY STOP — คำนวณบน Virtual Equity                            |
//+------------------------------------------------------------------+
bool CheckEquityStop() {
   if(!InpEnableEquityStop) return false;
   double vBal = GetVirtualBalance();
   double vEq  = GetVirtualEquity();
   if(vBal <= 0) return false;
   double dd = (vBal - vEq) / vBal * 100.0;

   double killPct = InpCombineMode ? InpCombineKillSwitch : InpKillSwitchPercent;
   double softPct = InpCombineMode ? InpCombineDDLimit    : InpSoftStopPercent;

   if(dd >= killPct) {
      CloseAll("KILL SWITCH VDD=" + DoubleToString(dd,2) + "%");
      TelegramSend("9AU_NDAQ100_COMBINE KILL SWITCH | VDD="
                  + DoubleToString(dd,2) + "% | EA REMOVED | VBal="
                  + DoubleToString(vBal,2));
      ExpertRemove();
      return true;
   }
   if(dd >= softPct) {
      CloseAll("Soft Stop VDD=" + DoubleToString(dd,2) + "%");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ON TICK                                                          |
//+------------------------------------------------------------------+
void OnTick() {

   if(CheckEquityStop()) return;
   UpdateDailyLoss();
   CheckDDAlert();
   CheckHouseMoney();

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
         if(atrVal > 0 && (firstPrice - bid) / atrVal >= InpMaxGridDepthATR) {
            CloseAll("Grid Depth " + DoubleToString((firstPrice-bid)/atrVal,1) + "x ATR");
            partialDone = false;
            return;
         }
      }
   }

   if(!IsNewBar()) return;
   if(EnableTimeFilter && !IsTradingTimeAllowed()) return;
   if(EnableNewsFilter && TimeCurrent() - lastNewsUpdate > 3600) UpdateNewsCalendar();
   if(IsNewsWindowActive()) return;

   // v1.2.1: Crisis Monitor — รันทุกบาร์หลัง gate (D1 CopyHigh efficient พอ)
   CheckCrisisMonitor();

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

   if(basket.buyCount == 0) {
      if(IsDailyLossExceeded()) return;
      if(GetADX() < InpADXMin) return;
      if(!IsBuySignal()) return;
      if(InpTrendEMA > 0) {
         double emaVal   = GetEMAValue();
         double priceVal = iClose(_Symbol, PERIOD_CURRENT, 1);
         if(priceVal <= emaVal || !IsEMARising()) return;
      }
      if(!IsExposureSafe()) return;

      double lot = GetSniperLot();
      if(step > 0) lot = MathRound(lot / step) * step;
      lot = MathMax(lot, minLot);

      if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_NDAQ100 Sniper")) {
         Print("[OPEN] Sniper Lot=", DoubleToString(lot,2),
               " VBal=", DoubleToString(GetVirtualBalance(),2),
               " Compound=", g_houseActive ? "ON" : "OFF");
         ulong ticket = trade.ResultOrder();
         if(ticket > 0) SetHardSL(ticket, atrVal);
      } else {
         Print("[FAIL] Sniper Err=", GetLastError());
      }
   }
   else if(basket.buyCount < InpMaxOrders) {
      if(IsDailyLossExceeded()) return;
      if(ask < basket.lastBuyPrice - dynamicDist) {
         if(!IsExposureSafe()) return;
         double lot = CalculateSmartLot(basket.buyCount, basket.lastBuyLot);
         if(step > 0) lot = MathRound(lot / step) * step;
         lot = MathMax(lot, minLot);
         if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_NDAQ100 Grid")) {
            Print("[OPEN] Grid #", basket.buyCount+1, " Lot=", DoubleToString(lot,2));
            ulong ticket = trade.ResultOrder();
            if(ticket > 0) SetHardSL(ticket, atrVal);
         } else {
            Print("[FAIL] Grid Err=", GetLastError());
         }
      }
   }
}
//+------------------------------------------------------------------+
