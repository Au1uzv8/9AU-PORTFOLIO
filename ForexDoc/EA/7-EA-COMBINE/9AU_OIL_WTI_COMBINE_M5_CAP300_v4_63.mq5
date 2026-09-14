//+------------------------------------------------------------------+
//|        9AU_OIL_COMBINE_M5_CAP300.mq5                             |
//|        James Consultant | Compound Type | Forward Test Ready     |
//|        Magic 919293 | CAP $300 | House Money Architecture        |
//+------------------------------------------------------------------+
//  DUAL-BASKET ISOLATION PITFALL GUARD CHECKLIST (built-in):
//  [P1] buyBasketProfit / sellBasketProfit แยกกันเด็ดขาด
//  [P2] Buy TP ใช้ buyBasketProfit เท่านั้น — ไม่ใช้ totalProfit
//  [P3] Sell TP ใช้ sellBasketProfit เท่านั้น — ไม่ใช้ totalProfit
//  [P4] CloseAllBuy() แยกจาก CloseAllSell() แยกจาก CloseAll()
//  [P5] Sell entry guard: buyCount > 0 → skip Sell block ทันที
//  [P6] Buy entry guard: sellCount > 0 → skip Buy Sniper ทันที
//  [P7] compoundBrake ต้องอยู่ใน GetSellSniperLot() ด้วย ไม่ใช่แค่ GetSniperLot()
//  [P8] Sell SL = 3.5xATR (ตื้นกว่า Buy 8xATR) — cut loss เร็วบน counter-trend
//  [P9] Sell Exposure cap = 50% ของ Buy allowance
//  [P10] Trail threshold ใช้ buyBasketProfit / sellBasketProfit แยกกัน
//  [P11] Virtual Balance/Equity per Magic - รองรับรันร่วมบัญชีกับ EA อื่น
//        ใน Port เดียวกัน (Port-Combine)
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "4.63"
#property strict
//  [P12] v4.63: เพิ่ม InpDCAtoAdd (Manual DCA, Cumulative Total) + Global Variable Delta Guard
//        + On-Chart Label — Pattern เดียวกับ Gold/USDJPY/AUDCAD

#include <Trade\Trade.mqh>
CTrade trade;

input int InpMagicNumber = 919293;

input group "=== Step A: Entry Filter ==="
input int              InpTrendEMA       = 200;   // EMA200 H4 — Buy only when price > EMA (uptrend)
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_H4;
input int              InpRSIPeriod      = 14;
input double           InpRSIUpperLevel  = 68.0;
input double           InpRSILowerLevel  = 50.0;

input group "=== Silver RSI Pro Filter ==="
input int    InpRSIPeriodH1     = 14;
input double InpRSILowerLevelH1 = 50.0;
input double InpRSIUpperLevelH1 = 60.0;
input bool   InpUseDualTF       = true;
input int    InpRSIEntryMode    = 1;

input group "=== Step B: Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 5.0;
input double InpMinGridDistanceUSD = 0.3;    // ลดจาก 0.8 -> ATR*5 ต้อง < SL(ATR*8) เสมอ
input double InpInitialLot         = 0.05;
input double InpBaseMultiplier     = 1.25;
input double InpReductionStep      = 0.02;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 5;

input group "=== Step C: Sell Basket (Dual-Basket) ==="
input bool   InpEnableSell         = false;    // false = Buy-only baseline
input double InpSellSLMultiplier   = 3.5;      // [P8] ตื้นกว่า Buy 8x
input double InpSellTrailStartUSD  = 8.0;      // [P10] แยกจาก Buy 18.0
input double InpSellTrailStepATR   = 1.5;      // แยกจาก Buy 2.0
input double InpSellBasketTP       = 25.0;     // Sell TP แยกจาก Buy TP
input double InpSellExposurePct    = 0.5;      // [P9] 50% ของ Buy allowance

input group "=== Step D: Profit & Exit ==="
input double InpBasketTP           = 40.0;
input bool   InpEnablePartialClose = true;
input double InpPartialCloseLevel  = 0.50;
input double InpHardSLMultiplier   = 8.0;    // Must be > ATRMultiplier(5x) so Grid triggers before SL
input int    InpMinHoldBars        = 12;

input group "=== Step E: News Filter ==="
input bool   EnableNewsFilter      = true;
input int    NewsBeforeMinutes     = 60;
input int    NewsAfterMinutes      = 60;
input bool   NewsHighImpactOnly    = true;

input group "=== Step F: Safety & Protection ==="
input bool   InpEnableEquityStop   = true;
input double InpTrailStartUSD      = 18.0;
input double InpTrailStepATR       = 2.0;
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 0.02;
input double InpMaxSpreadBase      = 35.0;
input double InpMaxSpreadHighVol   = 40.0;
input double InpExposureFactor     = 0.10;
input double InpMaxExposurePercent = 300.0;
input double InpMinMarginLevel     = 300.0;

input group "=== Step G: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 6;
input int    TradingEndHour        = 2;
input bool   StopFridayAfterClose  = true;
input int    FridayCloseHour       = 18;

input group "=== Step H: Daily Loss Limit ==="
input bool   EnableDailyLossLimit  = true;
input double MaxDailyLossPercent   = 3.0;

input group "=== Step I: Kill Switch (3-Level HWM DD) ==="
input double InpWarnDD             = 8.0;     // Level 1: Warn (Compound Type)
input double InpFreezeDD           = 12.0;    // Level 2: Freeze (Compound Type)
input double InpKillDD             = 18.0;    // Level 3: Kill (Compound Type)

input group "=== Step J: House Money Architecture ==="
input double InpBaseBalance        = 300.0;   // Compound Type — Balance DD 0.95% < 18%
input double InpCapRecoveryPct     = 100.0;

input group "=== Step K: Compound Selective ==="
// Compound Selective: ใช้ Compound เฉพาะเมื่อ balance >= BaseBalance x Multiplier
// และหยุดชั่วคราวอัตโนมัติเมื่อ DD ถึง SoftBrake threshold
enum LOT_MODE { FIXED_LOT, COMPOUND_LOT };
input LOT_MODE InpLotMode              = COMPOUND_LOT;  // Compound Type default
input double   InpCompoundStartMult    = 1.5;   // เริ่ม Compound เมื่อ balance >= 300 x 1.5 = $450
input double   InpCompoundDDSoftBrake  = 15.0;  // DD >= 15% -> brake (Compound Type strict)
input double   InpCompoundMaxDD        = 22.0;  // DD >= 22% -> Kill (Compound Type)
input double   InpCompoundDailyLoss    = 3.0;   // Daily loss Compound mode (%)

input group "=== Step L: Telegram Notify ==="
input bool   InpEnableTelegram     = true;
input string InpToken              = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID             = "8053031320";

input group "=== Step N: Manual DCA (Cumulative Total, ไม่ใช่ยอดต่อเดือน) ==="
input double InpDCAtoAdd           = 0.0;    // กรอกเป็นยอด DCA สะสมทั้งหมดตั้งแต่เริ่ม (เดือน1=25, เดือน2=50 ...)

input group "=== Step M: Debug ==="
input bool   InpDebugGridTest         = false;
input double InpDebugGridDist         = 0.20;
input bool   InpDebugDisableExposure  = false;

//+------------------------------------------------------------------+
// STRUCTS
//+------------------------------------------------------------------+
struct BasketInfo {
   int      buyCount;
   int      sellCount;
   double   buyBasketProfit;    // [P1] แยกเด็ดขาด
   double   sellBasketProfit;   // [P1] แยกเด็ดขาด
   double   totalProfit;        // รวม — ใช้เฉพาะ Trail threshold เท่านั้น
   double   totalLots;
   double   lastBuyPrice;
   double   lastSellPrice;
   double   lastBuyLot;
   double   lastSellLot;
   datetime oldestBuyTime;
   datetime oldestSellTime;
};
BasketInfo basket;

//+------------------------------------------------------------------+
// GLOBALS
//+------------------------------------------------------------------+
datetime lastNewsUpdate    = 0;
MqlCalendarValue TodayEvents[];

datetime currentDay        = 0;
double   dailyStartBalance = 0.0;
bool     partialBuyDone    = false;
bool     partialSellDone   = false;

double   hwmEquity         = 0.0;
bool     killFreezeEntry   = false;
bool     killWarnSent      = false;
bool     killFreezeSent    = false;

bool     capRecoveryAlertSent = false;
int      blinkCounter      = 0;
datetime lastHouseMoneyTG  = 0;

// Compound Selective globals
bool     compoundActive    = false;  // true เมื่อ balance >= BaseBalance x StartMult
bool     compoundBrake     = false;  // true เมื่อ DD >= SoftBrake -> ใช้ Fixed ชั่วคราว
double   compoundHWM       = 0.0;    // HWM เฉพาะ Compound mode

int gridTriggeredCount = 0;

int g_handleRSI_M5   = INVALID_HANDLE;
int g_handleRSI_H1   = INVALID_HANDLE;
int g_handleATR      = INVALID_HANDLE;
int g_handleEMA      = INVALID_HANDLE;

// --- Virtual Balance/Equity per Magic Number (Port-Combine) ---
double   vRealizedProfit = 0.0;

//+------------------------------------------------------------------+
// VIRTUAL BALANCE / EQUITY (per Magic Number)
//+------------------------------------------------------------------+
void ScanInitialRealizedProfit() {
   vRealizedProfit = 0.0;
   if(!HistorySelect(0, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
      vRealizedProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
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
   vRealizedProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                    + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                    + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
}

double GetVirtualBalance() {
   return InpBaseBalance + vRealizedProfit;
}

double GetVirtualEquity() {
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
// MANUAL DCA — Cumulative Total + Global Variable Delta Guard (Pattern เดียวกับ Gold/USDJPY/AUDCAD)
//+------------------------------------------------------------------+
string GVName_DCA() { return "9AU_DCA_APPLIED_" + IntegerToString(InpMagicNumber); }

void ApplyDCAIfNeeded() {
   string gv = GVName_DCA();
   double lastApplied = GlobalVariableCheck(gv) ? GlobalVariableGet(gv) : 0.0;
   double delta = InpDCAtoAdd - lastApplied;
   if(MathAbs(delta) < 0.01) return;

   vRealizedProfit += delta;
   GlobalVariableSet(gv, InpDCAtoAdd);
   Print("[DCA] OIL-WTI Applied Delta=$", DoubleToString(delta,2),
         " | Cumulative Target=$", DoubleToString(InpDCAtoAdd,2),
         " | New VBal=$", DoubleToString(GetVirtualBalance(),2));
   if(InpEnableTelegram)
      TelegramSend("9AU_WTI_OIL DCA APPLIED | Delta=$" + DoubleToString(delta,2)
                   + " | Cumulative=$" + DoubleToString(InpDCAtoAdd,2)
                   + " | New VBal=$" + DoubleToString(GetVirtualBalance(),2));
}

void DrawDCALabel() {
   string name = "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber);
   double applied = GlobalVariableCheck(GVName_DCA()) ? GlobalVariableGet(GVName_DCA()) : 0.0;
   string txt = StringFormat("OIL-WTI(%d) DCA Cumulative=$%.2f | VBase=$%.2f | VBal=$%.2f",
                              InpMagicNumber, applied, InpBaseBalance, GetVirtualBalance());
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
// TELEGRAM
//+------------------------------------------------------------------+
void TelegramSend(string msg) {
   if(!InpEnableTelegram) return;
   string url  = "https://api.telegram.org/bot" + InpToken + "/sendMessage";
   string hdr  = "Content-Type: application/x-www-form-urlencoded\r\n";
   string body = "chat_id=" + InpChatID + "&text=" + msg;
   char req[], res[]; string resHdr;
   StringToCharArray(body, req, 0, StringLen(body));
   int code = WebRequest("POST", url, hdr, 5000, req, res, resHdr);
   if(code != 200) Print("[TG] Failed HTTP=", code, " Err=", GetLastError());
}

//+------------------------------------------------------------------+
// DAILY LOSS — Closed P/L only
//+------------------------------------------------------------------+
void UpdateDailyLoss() {
   datetime today = TimeCurrent() / 86400 * 86400;
   if(today != currentDay) {
      currentDay        = today;
      dailyStartBalance = GetVirtualBalance();
      partialBuyDone    = false;
      partialSellDone   = false;
   }
}

bool IsDailyLossExceeded() {
   if(!EnableDailyLossLimit) return false;
   double bal   = GetVirtualBalance();
   double limit = dailyStartBalance * MaxDailyLossPercent / 100.0;
   double loss  = dailyStartBalance - bal;
   return (loss >= limit);
}

//+------------------------------------------------------------------+
// HIGH WATER MARK
//+------------------------------------------------------------------+
void UpdateHWM() {
   double eq = GetVirtualEquity();
   if(eq > hwmEquity) hwmEquity = eq;
}

double GetHWMDrawdown() {
   if(hwmEquity <= 0) return 0.0;
   return (hwmEquity - GetVirtualEquity()) / hwmEquity * 100.0;
}

//+------------------------------------------------------------------+
// KILL SWITCH — 3-level
//+------------------------------------------------------------------+
void CheckKillSwitch() {
   double dd = GetHWMDrawdown();

   if(dd >= InpWarnDD && !killWarnSent) {
      killWarnSent = true;
      TelegramSend("9AU_WTI_OIL KILL-L1 WARNING | DD=" + DoubleToString(dd,2) +
                   "% | HWM=" + DoubleToString(hwmEquity,2) +
                   " | Eq=" + DoubleToString(GetVirtualEquity(),2));
   }
   if(dd >= InpFreezeDD && !killFreezeSent) {
      killFreezeEntry = true;
      killFreezeSent  = true;
      TelegramSend("9AU_WTI_OIL KILL-L2 FREEZE | DD=" + DoubleToString(dd,2) + "%");
   }
   if(dd < InpWarnDD) {
      killFreezeEntry = false;
      killWarnSent    = false;
      killFreezeSent  = false;
   }
   if(dd >= InpKillDD) {
      TelegramSend("9AU_WTI_OIL KILL-L3 SHUTDOWN | DD=" + DoubleToString(dd,2) +
                   "% | Bal=" + DoubleToString(GetVirtualBalance(),2));
      CloseAll("KILL SWITCH L3");
      ExpertRemove();
   }
}

//+------------------------------------------------------------------+
// COMPOUND SELECTIVE — activate / brake / kill logic
//+------------------------------------------------------------------+
void UpdateCompoundSelective() {
   if(InpLotMode != COMPOUND_LOT) return;

   double bal = GetVirtualBalance();
   double eq  = GetVirtualEquity();

   // Activate Compound เมื่อ balance ถึง threshold
   if(!compoundActive && bal >= InpBaseBalance * InpCompoundStartMult) {
      compoundActive = true;
      compoundHWM    = eq;
      TelegramSend("9AU_WTI_OIL COMPOUND ACTIVATED | Bal=" + DoubleToString(bal,2) +
                   " | Lot scaling ON");
      Print("[COMPOUND] Activated. Balance=", bal);
   }

   if(!compoundActive) return;

   // อัพเดต Compound HWM
   if(eq > compoundHWM) compoundHWM = eq;

   // คำนวณ Compound DD จาก compoundHWM
   double cDD = (compoundHWM > 0) ? (compoundHWM - eq) / compoundHWM * 100.0 : 0.0;

   // SoftBrake ON
   if(!compoundBrake && cDD >= InpCompoundDDSoftBrake) {
      compoundBrake = true;
      TelegramSend("9AU_WTI_OIL COMPOUND BRAKE ON | DD=" + DoubleToString(cDD,2) +
                   "% -> Lot Fixed ชั่วคราว");
      Print("[COMPOUND BRAKE] ON. DD=", cDD);
   }

   // SoftBrake OFF เมื่อ DD ฟื้นกลับ 75% ของ SoftBrake threshold
   if(compoundBrake && cDD < InpCompoundDDSoftBrake * 0.75) {
      compoundBrake = false;
      TelegramSend("9AU_WTI_OIL COMPOUND BRAKE OFF | DD=" + DoubleToString(cDD,2) +
                   "% -> Lot Compound กลับมา");
      Print("[COMPOUND BRAKE] OFF. DD=", cDD);
   }

   // Kill Switch Compound
   if(cDD >= InpCompoundMaxDD) {
      TelegramSend("9AU_WTI_OIL COMPOUND KILL | DD=" + DoubleToString(cDD,2) +
                   "% >= " + DoubleToString(InpCompoundMaxDD,0) + "% | CloseAll");
      CloseAll("COMPOUND KILL SWITCH");
      ExpertRemove();
   }
}

// [P7] GetSniperLot และ GetSellSniperLot ต้องตรวจ compoundBrake ทั้งคู่
double GetSniperLot() {
   if(InpLotMode == FIXED_LOT || !compoundActive || compoundBrake)
      return InpInitialLot;
   double eq   = GetVirtualEquity();
   double lot  = NormalizeDouble(InpInitialLot * (eq / InpBaseBalance), 2);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lot = MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   return lot;
}

double GetSellSniperLot() {   // [P7] แยกฟังก์ชัน — compoundBrake ต้องอยู่ที่นี่ด้วย
   if(InpLotMode == FIXED_LOT || !compoundActive || compoundBrake)
      return InpInitialLot;
   double eq   = GetVirtualEquity();
   double lot  = NormalizeDouble(InpInitialLot * (eq / InpBaseBalance), 2);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lot = MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   return lot;
}

//+------------------------------------------------------------------+
// CAPITAL RECOVERY — blink label + Telegram ทุก 1 ชม.
//+------------------------------------------------------------------+
void CheckCapitalRecovery() {
   double bal    = GetVirtualBalance();
   double eq     = GetVirtualEquity();
   double target = InpBaseBalance * (1.0 + InpCapRecoveryPct / 100.0);

   if(bal < target) {
      if(ObjectFind(0, "LBL_HOUSEMONEY") >= 0)
         ObjectDelete(0, "LBL_HOUSEMONEY");
      capRecoveryAlertSent = false;
      return;
   }

   // Blink
   blinkCounter++;
   string lbl = "LBL_HOUSEMONEY";
   if(ObjectFind(0, lbl) < 0) ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE,  14);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, (blinkCounter % 2 == 0) ? clrYellow : clrRed);
   ObjectSetString(0, lbl, OBJPROP_TEXT,
      "WITHDRAW CAPITAL NOW | Profit 100% | Balance=" + DoubleToString(bal,2));
   ChartRedraw(0);

   // One-time Alert
   if(!capRecoveryAlertSent) {
      capRecoveryAlertSent = true;
      Alert("HOUSE MONEY | Bal=" + DoubleToString(bal,2) + " | Withdraw $" + DoubleToString(InpBaseBalance,0));
   }

   // Telegram ทุก 1 ชั่วโมง
   if(TimeCurrent() - lastHouseMoneyTG >= 3600) {
      lastHouseMoneyTG = TimeCurrent();
      TelegramSend("HOUSE MONEY ALERT 9AU_WTI_OIL v4" +
                   "\nBalance = " + DoubleToString(bal,2) +
                   "\nEquity  = " + DoubleToString(eq,2) +
                   "\nWithdraw = " + DoubleToString(InpBaseBalance,0) + " USD" +
                   "\nRestart EA with Capital = " + DoubleToString(InpBaseBalance,0) + " USD");
   }
}

//+------------------------------------------------------------------+
// UPDATE BASKET INFO — [P1] แยก buyBasketProfit / sellBasketProfit
//+------------------------------------------------------------------+
void UpdateBasketInfo() {
   basket.buyCount        = 0;
   basket.sellCount       = 0;
   basket.buyBasketProfit = 0;   // [P1]
   basket.sellBasketProfit= 0;   // [P1]
   basket.totalProfit     = 0;
   basket.totalLots       = 0;
   basket.lastBuyPrice    = 0;
   basket.lastSellPrice   = 0;
   basket.lastBuyLot      = 0;
   basket.lastSellLot     = 0;
   basket.oldestBuyTime   = TimeCurrent() + 86400 * 365;
   basket.oldestSellTime  = TimeCurrent() + 86400 * 365;

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      double lot     = PositionGetDouble(POSITION_VOLUME);
      double price   = PositionGetDouble(POSITION_PRICE_OPEN);
      double profit  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime oTime = (datetime)PositionGetInteger(POSITION_TIME);

      basket.totalProfit += profit;
      basket.totalLots   += lot;

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         basket.buyCount++;
         basket.buyBasketProfit += profit;   // [P1]
         basket.lastBuyLot       = lot;
         basket.lastBuyPrice     = price;
         if(oTime < basket.oldestBuyTime) basket.oldestBuyTime = oTime;
      } else {
         basket.sellCount++;
         basket.sellBasketProfit += profit;  // [P1]
         basket.lastSellLot       = lot;
         basket.lastSellPrice     = price;
         if(oTime < basket.oldestSellTime) basket.oldestSellTime = oTime;
      }
   }
   if(basket.buyCount  == 0) basket.oldestBuyTime  = 0;
   if(basket.sellCount == 0) basket.oldestSellTime = 0;
}

//+------------------------------------------------------------------+
// RSI SIGNAL
//+------------------------------------------------------------------+
bool IsBuySignal() {
   double buf[];
   ArraySetAsSeries(buf, true);
   ArrayResize(buf, 2);
   if(CopyBuffer(g_handleRSI_M5, 0, 0, 2, buf) < 2) return false;
   double m5c = buf[0], m5p = buf[1];
   double h1c = 0, h1p = 0;
   if(InpUseDualTF && g_handleRSI_H1 != INVALID_HANDLE) {
      if(CopyBuffer(g_handleRSI_H1, 0, 0, 2, buf) < 2) return false;
      h1c = buf[0]; h1p = buf[1];
   }
   bool sm5, sh1;
   if(InpRSIEntryMode == 0) {
      sm5 = (m5c < InpRSILowerLevel);
      sh1 = (!InpUseDualTF || h1c < InpRSILowerLevelH1);
   } else {
      sm5 = (m5c > InpRSILowerLevel && m5p <= InpRSILowerLevel);
      sh1 = (!InpUseDualTF || (h1c > InpRSILowerLevelH1 && h1p <= InpRSILowerLevelH1));
   }
   return (sm5 && sh1);
}

bool IsSellSignal() {
   double buf[];
   ArraySetAsSeries(buf, true);
   ArrayResize(buf, 2);
   if(CopyBuffer(g_handleRSI_M5, 0, 0, 2, buf) < 2) return false;
   double m5c = buf[0], m5p = buf[1];
   double h1c = 0, h1p = 0;
   if(InpUseDualTF && g_handleRSI_H1 != INVALID_HANDLE) {
      if(CopyBuffer(g_handleRSI_H1, 0, 0, 2, buf) < 2) return false;
      h1c = buf[0]; h1p = buf[1];
   }
   bool sm5, sh1;
   if(InpRSIEntryMode == 0) {
      sm5 = (m5c > InpRSIUpperLevel);
      sh1 = (!InpUseDualTF || h1c > InpRSIUpperLevelH1);
   } else {
      sm5 = (m5c < InpRSIUpperLevel && m5p >= InpRSIUpperLevel);
      sh1 = (!InpUseDualTF || (h1c < InpRSIUpperLevelH1 && h1p >= InpRSIUpperLevelH1));
   }
   return (sm5 && sh1);
}

//+------------------------------------------------------------------+
// ATR / EMA
//+------------------------------------------------------------------+
double GetATR() {
   if(g_handleATR == INVALID_HANDLE) return 0.0;
   double buf[]; ArrayResize(buf, 1);
   if(CopyBuffer(g_handleATR, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetEMA() {
   if(InpTrendEMA <= 0 || g_handleEMA == INVALID_HANDLE) return 0.0;
   double buf[]; ArrayResize(buf, 1);
   if(CopyBuffer(g_handleEMA, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
// LOT HELPERS
//+------------------------------------------------------------------+
bool IsMinHoldPassed(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return true;
   datetime oTime = (datetime)PositionGetInteger(POSITION_TIME);
   return (Bars(_Symbol, PERIOD_M5, oTime, TimeCurrent()) >= InpMinHoldBars);
}

double CalculateSmartLot(int count, double lastLot) {
   double m    = InpBaseMultiplier - (count * InpReductionStep);
   if(m < InpMinMultiplier) m = InpMinMultiplier;
   double lot  = NormalizeDouble(lastLot * m, 2);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, step);
   lot = MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   return lot;
}

//+------------------------------------------------------------------+
// EXPOSURE SAFETY
//+------------------------------------------------------------------+
bool IsBuyExposureSafe() {
   if(InpDebugGridTest && InpDebugDisableExposure) return true;
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel > 0 && marginLevel < InpMinMarginLevel) return false;
   double bal      = GetVirtualBalance();
   double maxExp   = bal * InpMaxExposurePercent / 100.0;
   double cSize    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double exposure = basket.totalLots * cSize * bid * InpExposureFactor;
   if(exposure > maxExp && basket.buyCount > 0) return false;
   return true;
}

bool IsSellExposureSafe() {  // [P9] cap 50% ของ Buy allowance
   if(InpDebugGridTest && InpDebugDisableExposure) return true;
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel > 0 && marginLevel < InpMinMarginLevel) return false;
   double bal      = GetVirtualBalance();
   double maxExp   = bal * InpMaxExposurePercent / 100.0 * InpSellExposurePct;   // [P9]
   double cSize    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double exposure = basket.totalLots * cSize * ask * InpExposureFactor;
   if(exposure > maxExp && basket.sellCount > 0) return false;
   return true;
}

//+------------------------------------------------------------------+
// HARD SL
//+------------------------------------------------------------------+
void SetHardSL(ulong ticket, double atr, bool isSell = false) {
   if(!PositionSelectByTicket(ticket)) return;
   double curSL  = PositionGetDouble(POSITION_SL);
   double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
   double mult   = isSell ? InpSellSLMultiplier : InpHardSLMultiplier;
   double dist   = atr * mult;   // 2xATR for Buy, 3.5xATR for Sell [P8]
   double newSL;
   if(!isSell) {
      newSL = NormalizeDouble(openPx - dist, _Digits);
      if(curSL == 0 || newSL > curSL) trade.PositionModify(ticket, newSL, 0);
   } else {
      newSL = NormalizeDouble(openPx + dist, _Digits);
      if(curSL == 0 || newSL < curSL) trade.PositionModify(ticket, newSL, 0);
   }
}

void ApplyHardSLAll(double atr) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetDouble(POSITION_SL) == 0) {
         bool isSell = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL);
         SetHardSL(t, atr, isSell);
      }
   }
}

//+------------------------------------------------------------------+
// CLOSE HELPERS — [P4] แยกเด็ดขาด
//+------------------------------------------------------------------+
void CloseAllBuy(string reason) {   // [P4]
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         trade.PositionClose(t);
   }
   Print("[CLOSE BUY] ", reason);
   partialBuyDone = false;
}

void CloseAllSell(string reason) {  // [P4]
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         trade.PositionClose(t);
   }
   Print("[CLOSE SELL] ", reason);
   partialSellDone = false;
}

void CloseAll(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      trade.PositionClose(t);
   }
   Print("[CLOSE ALL] ", reason);
   partialBuyDone  = false;
   partialSellDone = false;
   if(InpEnableTelegram) TelegramSend("9AU_WTI_OIL CLOSE ALL | " + reason);
}

//+------------------------------------------------------------------+
// PARTIAL CLOSE — แยก Buy / Sell
//+------------------------------------------------------------------+
void PartialCloseBuyBasket() {
   if(!InpEnablePartialClose || partialBuyDone) return;
   if(basket.buyBasketProfit < InpBasketTP * InpPartialCloseLevel) return;  // [P2]
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double half = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / step) * step;
      if(half >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         trade.PositionClosePartial(t, half);
   }
   partialBuyDone = true;
}

void PartialCloseSellBasket() {
   if(!InpEnablePartialClose || partialSellDone) return;
   if(basket.sellBasketProfit < InpSellBasketTP * InpPartialCloseLevel) return;  // [P3]
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double half = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / step) * step;
      if(half >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         trade.PositionClosePartial(t, half);
   }
   partialSellDone = true;
}

//+------------------------------------------------------------------+
// TRAIL — แยก Buy / Sell ใช้ BasketProfit แต่ละ basket [P10]
//+------------------------------------------------------------------+
void TrailBuyBasket(double atr) {
   if(basket.buyBasketProfit < InpTrailStartUSD) return;   // [P10]
   double dist = atr * InpTrailStepATR;
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_BUY) continue;
      if(!IsMinHoldPassed(t)) continue;
      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = NormalizeDouble(bid - dist, _Digits);
      if(newSL > curSL) trade.PositionModify(t, newSL, 0);
   }
}

void TrailSellBasket(double atr) {
   if(basket.sellBasketProfit < InpSellTrailStartUSD) return;  // [P10]
   double dist = atr * InpSellTrailStepATR;
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_SELL) continue;
      if(!IsMinHoldPassed(t)) continue;
      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = NormalizeDouble(ask + dist, _Digits);
      if(curSL == 0 || newSL < curSL) trade.PositionModify(t, newSL, 0);
   }
}

//+------------------------------------------------------------------+
// TIME / NEWS / SPREAD
//+------------------------------------------------------------------+
bool IsNewBar() {
   static datetime lastBar = 0;
   datetime cur = iTime(_Symbol, PERIOD_M5, 0);
   if(cur != lastBar) { lastBar = cur; return true; }
   return false;
}

bool IsTradingTimeAllowed() {
   if(!EnableTimeFilter) return true;
   MqlDateTime dt; TimeLocal(dt);
   int h = dt.hour, dow = dt.day_of_week;
   if(dow >= 1 && dow <= 4) return (h >= TradingStartHour || h < TradingEndHour);
   if(dow == 5) {
      if(StopFridayAfterClose) return (h >= TradingStartHour && h < FridayCloseHour);
      else return (h >= TradingStartHour || h < TradingEndHour);
   }
   return false;
}

void UpdateNewsCalendar() {
   datetime from = TimeCurrent(), to = from + 86400 * 3;
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
      datetime eTime = TodayEvents[i].time;
      if(now >= eTime - NewsBeforeMinutes*60 && now <= eTime + NewsAfterMinutes*60) return true;
   }
   return false;
}

void CheckTimeExit() {
   if(basket.oldestBuyTime > 0 &&
      TimeCurrent() - basket.oldestBuyTime > InpMaxHoldDays * 86400)
      CloseAllBuy("Time Exit Buy");
   if(basket.oldestSellTime > 0 &&
      TimeCurrent() - basket.oldestSellTime > InpMaxHoldDays * 86400)
      CloseAllSell("Time Exit Sell");
}

//+------------------------------------------------------------------+
// OnInit
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);

   ScanInitialRealizedProfit();   // กู้คืนกำไร/ขาดทุนสะสมเฉพาะ Magic นี้จาก History
   ApplyDCAIfNeeded();
   DrawDCALabel();
   hwmEquity         = GetVirtualEquity();
   compoundHWM       = hwmEquity;
   dailyStartBalance = GetVirtualBalance();
   currentDay        = TimeCurrent() / 86400 * 86400;
   gridTriggeredCount = 0;

   g_handleRSI_M5 = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   if(g_handleRSI_M5 == INVALID_HANDLE) return INIT_FAILED;

   if(InpUseDualTF) {
      g_handleRSI_H1 = iRSI(_Symbol, PERIOD_H1, InpRSIPeriodH1, PRICE_CLOSE);
      if(g_handleRSI_H1 == INVALID_HANDLE) return INIT_FAILED;
   }

   g_handleATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(g_handleATR == INVALID_HANDLE) return INIT_FAILED;

   if(InpTrendEMA > 0) {
      g_handleEMA = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(g_handleEMA == INVALID_HANDLE) return INIT_FAILED;
   }

   Print("=== 9AU_WTI_OIL v4.0 DUAL-BASKET + COMPOUND SELECTIVE ===");
   Print("CAP=", InpBaseBalance,
         " LotMode=", (InpLotMode == FIXED_LOT ? "FIXED" : "COMPOUND"),
         " CompoundStart=x", InpCompoundStartMult,
         " SoftBrake=", InpCompoundDDSoftBrake, "%",
         " EnableSell=", InpEnableSell);

   TelegramSend("9AU_WTI_OIL v4.0 started" +
                " | CAP=" + DoubleToString(InpBaseBalance,0) +
                " | Mode=" + (InpLotMode == FIXED_LOT ? "FIXED" : "COMPOUND") +
                " | Sell=" + (InpEnableSell ? "ON" : "OFF") +
                " | Target=$" + DoubleToString(InpBaseBalance * 2.0, 0));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
// OnDeinit
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(ObjectFind(0, "LBL_HOUSEMONEY") >= 0) ObjectDelete(0, "LBL_HOUSEMONEY");
   ObjectDelete(0, "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber));
   if(g_handleRSI_M5 != INVALID_HANDLE) IndicatorRelease(g_handleRSI_M5);
   if(g_handleRSI_H1 != INVALID_HANDLE) IndicatorRelease(g_handleRSI_H1);
   if(g_handleATR    != INVALID_HANDLE) IndicatorRelease(g_handleATR);
   if(g_handleEMA    != INVALID_HANDLE) IndicatorRelease(g_handleEMA);
   Print("=== 9AU_WTI_OIL v4 Stopped. GridTriggered=", gridTriggeredCount, " ===");
   TelegramSend("9AU_WTI_OIL v4 Stopped | GridTriggered=" + IntegerToString(gridTriggeredCount));
}

//+------------------------------------------------------------------+
// OnTick
// v4.5: แยก Grid Entry ออกจาก IsNewBar block
//       Grid ตรวจทุก Tick — Sniper ตรวจเฉพาะ New Bar
//+------------------------------------------------------------------+
void OnTick() {
   UpdateHWM();
   CheckKillSwitch();
   UpdateCompoundSelective();
   UpdateDailyLoss();
   CheckCapitalRecovery();

   if(IsDailyLossExceeded()) return;
   if(killFreezeEntry) return;

   // ---- ส่วนที่ทำทุก Tick (Basket + Grid) ----
   double atr = GetATR();
   if(atr < InpMinATRThreshold) return;

   UpdateBasketInfo();
   ApplyHardSLAll(atr);

   //--- BUY BASKET MANAGEMENT (ทุก Tick)
   if(basket.buyCount > 0) {
      TrailBuyBasket(atr);
      PartialCloseBuyBasket();
      if(basket.buyBasketProfit >= InpBasketTP) {   // [P2]
         Print("[BUY TP] Profit=", basket.buyBasketProfit);
         CloseAllBuy("Buy Basket TP");
         return;
      }
   }

   //--- SELL BASKET MANAGEMENT (ทุก Tick)
   if(InpEnableSell && basket.sellCount > 0) {
      TrailSellBasket(atr);
      PartialCloseSellBasket();
      if(basket.sellBasketProfit >= InpSellBasketTP) {   // [P3]
         Print("[SELL TP] Profit=", basket.sellBasketProfit);
         CloseAllSell("Sell Basket TP");
         return;
      }
   }

   double dynamicDist = InpDebugGridTest ? InpDebugGridDist :
                        (InpEnableDynamicGrid ? MathMax(atr * InpATRMultiplier, InpMinGridDistanceUSD)
                                             : InpMinGridDistanceUSD);

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   //==================================================================
   // GRID ENTRY — ตรวจทุก Tick (ไม่รอ New Bar)
   // [P6] Sell basket มีอยู่ -> ข้าม Buy Grid
   //==================================================================
   if(basket.sellCount == 0 && basket.buyCount > 0 && basket.buyCount < InpMaxOrders) {
      if(ask < basket.lastBuyPrice - dynamicDist) {
         gridTriggeredCount++;
         if(IsBuyExposureSafe()) {
            double lot = CalculateSmartLot(basket.buyCount, basket.lastBuyLot);
            if(step > 0) lot = MathRound(lot / step) * step;
            lot = MathMax(lot, minLot);
            if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_WTI_OIL Grid")) {
               Print("[BUY GRID #", basket.buyCount+1, "] Lot=", lot,
                     " Dist=", DoubleToString(dynamicDist, 2));
               ulong tk = trade.ResultOrder();
               if(tk > 0) SetHardSL(tk, atr, false);
            }
         }
         return;   // ป้องกัน double-fire ใน tick เดียวกัน
      }
   }

   // ---- ส่วนที่ทำเฉพาะ New Bar (Sniper + Time/News check) ----
   if(!IsNewBar()) return;
   if(EnableTimeFilter && !IsTradingTimeAllowed()) return;
   if(EnableNewsFilter && TimeCurrent() - lastNewsUpdate > 3600) UpdateNewsCalendar();
   if(IsNewsWindowActive()) return;

   // Spread check (New Bar เท่านั้น — ไม่ block Grid ที่ต้องรีบเข้า)
   double spreadPrice = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double maxSpread   = (atr > 1.0) ? InpMaxSpreadHighVol * SymbolInfoDouble(_Symbol, SYMBOL_POINT)
                                    : InpMaxSpreadBase    * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(spreadPrice > maxSpread) return;

   CheckTimeExit();

   //==================================================================
   // BUY SNIPER — New Bar เท่านั้น [P6]
   //==================================================================
   if(basket.sellCount == 0 && basket.buyCount == 0) {
      if(IsBuySignal()) {
         double emaVal = GetEMA();
         bool emaOk = (InpTrendEMA <= 0 || iClose(_Symbol, PERIOD_CURRENT, 1) > emaVal);
         if(emaOk && IsBuyExposureSafe()) {
            double lot = GetSniperLot();
            if(step > 0) lot = MathRound(lot / step) * step;
            lot = MathMax(lot, minLot);
            if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_WTI_OIL Sniper")) {
               Print("[BUY SNIPER] Lot=", lot, " Ask=", ask);
               ulong tk = trade.ResultOrder();
               if(tk > 0) SetHardSL(tk, atr, false);
            }
         }
      }
   }

   //==================================================================
   // SELL SNIPER — New Bar เท่านั้น [P5]
   //==================================================================
   if(!InpEnableSell) return;
   if(basket.buyCount > 0) return;   // [P5] Isolation guard

   if(basket.sellCount == 0) {
      if(IsSellSignal()) {
         double emaVal = GetEMA();
         bool emaOk = (InpTrendEMA <= 0 || iClose(_Symbol, PERIOD_CURRENT, 1) < emaVal);
         if(emaOk && IsSellExposureSafe()) {
            double lot = GetSellSniperLot();   // [P7]
            if(step > 0) lot = MathRound(lot / step) * step;
            lot = MathMax(lot, minLot);
            if(trade.Sell(lot, _Symbol, bid, 0, 0, "9AU_WTI_OIL Sell Sniper")) {
               Print("[SELL SNIPER] Lot=", lot, " Bid=", bid);
               ulong tk = trade.ResultOrder();
               if(tk > 0) SetHardSL(tk, atr, true);   // [P8] SL = 3.5xATR
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
