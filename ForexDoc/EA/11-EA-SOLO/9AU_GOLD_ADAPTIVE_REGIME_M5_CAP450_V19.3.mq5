//+------------------------------------------------------------------+
//|         9AU_GOLD_ADAPTIVE_REGIME_M5_CAP450.mq5                   |
//|  James Consultant | House Money + Compound Lot | v19.3           |
//|  Magic 919291 | Kill Switch DD 25% -> ExpertRemove()             |
//|  Stage 1: Fixed Lot | Stage 2: Compound or Withdraw+Reset        |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "19.3"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//  INPUTS
//+------------------------------------------------------------------+
input int    InpMagicNumber      = 919291;

input group "=== Step A: Filter (Buy - Original v14) ==="
input int              InpTrendEMA       = 200;
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_H4;
input int              InpRSIPeriod      = 14;
input double           InpRSILowerLevel  = 42.0;
input double           InpRSIUpperLevel  = 68.0;

input group "=== Step B: Buy Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 6.5;
input double InpInitialLot         = 0.01;   // Base lot (Stage 1)
input double InpBaseMultiplier     = 1.15;
input double InpReductionStep      = 0.05;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 5;

input group "=== Step B2: Sell Grid (Conservative) ==="
input bool   InpEnableSell           = false;
input double InpSellInitialLot       = 0.01;
input double InpSellATRMultiplier    = 9.75;
input double InpSellBaseMultiplier   = 1.05;
input double InpSellReductionStep    = 0.02;
input double InpSellMinMultiplier    = 1.02;
input int    InpSellMaxOrders        = 5;
input double InpSellBasketTP         = 16.0;
input double InpSellHardSLMultiplier = 3.5;
input double InpSellTrailStartUSD    = 8.0;
input double InpSellTrailStepATR     = 1.5;

input group "=== Step I: Sell Regime Filter ==="
input int    InpADXPeriod        = 14;
input double InpADXTrendHigh     = 28.0;
input int    InpEMA50Period      = 50;
input double InpEMASlopeATRMult  = 0.08;
input int    InpEMASlopeLookback = 20;
input double InpRSITrendLow      = 43.0;
input double InpRSITrendHigh     = 57.0;
// --- Sell Quality Filter (Layer 3 & 4) ---
input double InpSellMinATRMult   = 1.2;    // Layer 3: ATR > AvgATR x this = volatile market only
input int    InpAvgATRPeriod     = 50;     // Period for Average ATR baseline
input int    InpResistLookback   = 96;     // Layer 4: Resistance lookback bars (H4 bars = 96 x M5)
input double InpResistBuffer     = 0.003;  // Price must be this % below resistance (0.3%)

input group "=== Step C: Profit & Exit ==="
input double InpBasketTP           = 18.0;
input bool   InpEnablePartialClose = true;
input double InpPartialCloseLevel  = 0.70;
input double InpHardSLMultiplier   = 11.0;
input int    InpMinHoldBars        = 12;

input group "=== Step D: News Filter ==="
input bool   EnableNewsFilter      = true;
input int    NewsBeforeMinutes     = 60;
input int    NewsAfterMinutes      = 60;
input bool   NewsHighImpactOnly    = true;

input group "=== Step E: Safety & Protection ==="
input bool   InpEnableEquityStop   = true;
input double InpMaxDrawdownPercent = 25.0;   // Kill Switch -> ExpertRemove
input double InpTrailStartUSD      = 12.0;
input double InpTrailStepATR       = 2.5;
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 3.5;
input double InpMaxSpreadBase      = 35.0;
input double InpMaxSpreadHighVol   = 40.0;
input double InpMaxExposurePercent = 12.5;
input double InpMinMarginLevel     = 700.0;

input group "=== Step F: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 6;
input int    TradingEndHour        = 2;
input bool   StopFridayAfterClose  = true;
input int    FridayCloseHour       = 18;

input group "=== Step G: Daily Loss Limit ==="
input bool   EnableDailyLossLimit        = true;
input double MaxDailyLossPercent         = 2.25;
input double InpDailyLossCloseAllPercent = 5.0;

input group "=== Step H: Telegram Notify ==="
input bool   InpEnableTelegram   = true;
input string InpToken            = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID           = "8053031320";
input double InpTelegramDDAlert  = 15.0;
input bool   InpEnable2xAlert    = true;
input double InpBaseBalance      = 450.0;   // ทุนเริ่มต้น

input group "=== Step L: House Money & Compound ==="
input bool   InpEnableHouseMoney        = false;
input double InpHouseMoneyTarget        = 2.0;    // x เท่าของ BaseBalance = 100% profit
input bool   InpEnableCompound          = true;   // true=Compound, false=รอ Withdraw manual
input double InpCompoundStartMultiple   = 1.5;    // เริ่ม compound เมื่อ balance > Base x นี้ (ป้องกัน scale เร็วเกิน)
input double InpCompoundMaxLot          = 0.10;   // Lot สูงสุดใน Compound mode
input double InpCompoundDailyLossClose  = 3.0;    // Daily Loss CloseAll ใน Compound mode (แคบกว่า Fixed)
input double InpCompoundDDSoftBrake     = 20.0;   // DD% threshold: ลด lot กลับ Fixed ชั่วคราว (ก่อนถึง Kill Switch)
input double InpCompoundMaxDD           = 28.0;   // Kill Switch DD% ขณะ Compound (กว้างกว่า Fixed 25%)

input group "=== Step J: Diagnostic ==="
input bool InpDiagnosticLog      = true;

//+------------------------------------------------------------------+
//  ENUMS
//+------------------------------------------------------------------+
enum LOT_MODE { LOT_FIXED, LOT_COMPOUND };

//+------------------------------------------------------------------+
//  GLOBALS
//+------------------------------------------------------------------+
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

double buyBasketProfit  = 0.0;
double sellBasketProfit = 0.0;

// Daily Loss
datetime currentDay       = 0;
double   dayStartBalance  = 0.0;
double   dayLowestEquity  = 0.0;
double   dailyLossPercent = 0.0;
bool     dailyLossClosed  = false;
bool     partialDone      = false;
bool     partialDoneSell  = false;

// Peak equity for DD
double   peakEquity       = 0.0;
// High Water Mark for Compound Lot - ป้องกัน scale lot ระหว่าง DD
double   compoundHWM      = 0.0;   // peak balance ขณะ compound mode active
bool     compoundBrake    = false; // true=ลด lot กลับ Fixed ชั่วคราวเมื่อ DD > SoftBrake

// Alerts
bool     ddAlertSent      = false;
datetime lastDDAlertTime  = 0;
int      last2xLevel      = 1;

// House Money state
LOT_MODE currentLotMode   = LOT_FIXED;
bool     houseMoneyAlerted = false;
datetime lastHouseAlert   = 0;

// News
datetime lastNewsUpdate   = 0;
MqlCalendarValue TodayEvents[];

//+------------------------------------------------------------------+
//  TELEGRAM
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
   if(code == 200) Print("[TELEGRAM] Sent OK");
   else Print("[TELEGRAM] Failed HTTP=", code, " Err=", GetLastError());
}

//+------------------------------------------------------------------+
//  INIT / DEINIT
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   peakEquity    = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance = bal;
   dayLowestEquity = bal;
   last2xLevel   = (int)MathFloor(bal / InpBaseBalance);
   if(last2xLevel < 1) last2xLevel = 1;

   // Determine starting lot mode
   currentLotMode   = (bal >= InpBaseBalance * InpCompoundStartMultiple && InpEnableCompound)
                      ? LOT_COMPOUND : LOT_FIXED;
   compoundHWM       = (currentLotMode == LOT_COMPOUND) ? bal : 0.0;
   houseMoneyAlerted = false;

   Print("=== 9AU_GOLD v19.0 | Mode=", (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"),
         " | BaseBalance=$", InpBaseBalance,
         " | Target=", InpHouseMoneyTarget, "x",
         " | MaxDD=", InpMaxDrawdownPercent, "% ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD v19 Started | " + _Symbol
                   + " | Balance $" + DoubleToString(bal,2)
                   + " | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED")
                   + " | Target $" + DoubleToString(InpBaseBalance*InpHouseMoneyTarget,0));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "HM_");   // ลบ label ทั้งหมด
   Print("=== 9AU_GOLD v19 Stopped. Reason=", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD v19 Stopped | Reason=" + IntegerToString(reason)
                   + " | Balance $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
}

//+------------------------------------------------------------------+
//  HOUSE MONEY: Label กระพริบ + Telegram
//+------------------------------------------------------------------+
void DrawBlinkLabel(string name, string text, color clr, int x, int y) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   }
   // กระพริบโดย toggle สี
   static bool blink = false;
   blink = !blink;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, blink ? clr : clrBlack);
   ChartRedraw();
}

void CheckHouseMoney() {
   if(!InpEnableHouseMoney) return;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double target = InpBaseBalance * InpHouseMoneyTarget;
   if(bal < target) {
      // ลบ label ถ้า balance ตกลงมา (เช่นหลัง withdrawal)
      ObjectDelete(0, "HM_LABEL");
      houseMoneyAlerted = false;
      return;
   }

   // วาด label กระพริบทุก tick
   string txt = "*** HOUSE MONEY REACHED $" + DoubleToString(bal,2)
                + " | WITHDRAW $" + DoubleToString(bal - InpBaseBalance,2)
                + " THEN RESET EA ***";
   DrawBlinkLabel("HM_LABEL", txt, clrYellow, 10, 30);

   // Telegram แจ้งเตือนครั้งแรก และทุก 1 ชั่วโมง
   datetime now = TimeCurrent();
   if(!houseMoneyAlerted || (now - lastHouseAlert) > 3600) {
      string msg = "*** HOUSE MONEY ALERT 9AU_GOLD ***"
                   + " | Balance $" + DoubleToString(bal,2)
                   + " (Target $" + DoubleToString(target,2) + " reached!)"
                   + " | PROFIT $" + DoubleToString(bal - InpBaseBalance,2)
                   + " | ACTION: Withdraw $" + DoubleToString(bal - InpBaseBalance,2)
                   + " then Reset EA with $" + DoubleToString(InpBaseBalance,0)
                   + " | OR: Enable Compound Mode auto-activates"
                   + " | " + _Symbol + " " + TimeToString(now, TIME_DATE|TIME_MINUTES);
      TelegramSend(msg);
      houseMoneyAlerted = true;
      lastHouseAlert    = now;
      Print("[HOUSE MONEY] Target reached! Balance=", DoubleToString(bal,2));
   }

   // Auto-switch to Compound mode เมื่อ balance > Base x InpCompoundStartMultiple
   double compoundThresh = InpBaseBalance * InpCompoundStartMultiple;
   if(InpEnableCompound && currentLotMode == LOT_FIXED && bal >= compoundThresh) {
      currentLotMode = LOT_COMPOUND;
      compoundHWM    = bal;   // set HWM เริ่มต้น
      Print("[COMPOUND] Mode activated at Balance=$", DoubleToString(bal,2),
            " | HWM=$", DoubleToString(compoundHWM,2));
      TelegramSend("9AU_GOLD COMPOUND MODE ON | Balance $" + DoubleToString(bal,2)
                   + " | HWM $" + DoubleToString(compoundHWM,2)
                   + " | MaxLot=" + DoubleToString(InpCompoundMaxLot,2));
   }
   // Update HWM เมื่อ balance ทำ new high
   if(currentLotMode == LOT_COMPOUND && bal > compoundHWM) {
      compoundHWM = bal;
      Print("[HWM] New High $", DoubleToString(compoundHWM,2));
   }
}

//+------------------------------------------------------------------+
//  COMPOUND LOT CALCULATION
//+------------------------------------------------------------------+
double GetSniperLot() {
   if(currentLotMode == LOT_FIXED || !InpEnableHouseMoney)
      return InpInitialLot;
   // Compound Brake: ถ้า DD > SoftBrake ให้ใช้ Fixed lot ชั่วคราว
   if(compoundBrake) return InpInitialLot;
   // HWM-based compound: scale จาก peak balance ไม่ใช่ equity ปัจจุบัน
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double basis = MathMin(bal, compoundHWM);   // ใช้ค่าต่ำกว่าระหว่าง balance กับ HWM
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot   = InpInitialLot * (basis / InpBaseBalance);
   lot = NormalizeDouble(lot, 2);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, minL);
   lot = MathMin(lot, InpCompoundMaxLot);
   Print("[COMPOUND LOT] Basis=$", DoubleToString(basis,2),
         " HWM=$", DoubleToString(compoundHWM,2),
         " Lot=", DoubleToString(lot,2));
   return lot;
}

double GetSellSniperLot() {
   if(currentLotMode == LOT_FIXED || !InpEnableHouseMoney)
      return InpSellInitialLot;
   if(compoundBrake) return InpSellInitialLot;
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double basis = MathMin(bal, compoundHWM);
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot   = InpSellInitialLot * (basis / InpBaseBalance);
   lot = NormalizeDouble(lot, 2);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, minL);
   lot = MathMin(lot, InpCompoundMaxLot);
   return lot;
}

//+------------------------------------------------------------------+
//  UTILITY
//+------------------------------------------------------------------+
bool IsNewBar() {
   static datetime lastBar = 0;
   datetime cur = iTime(_Symbol, PERIOD_M5, 0);
   if(cur != lastBar) { lastBar = cur; return true; }
   return false;
}

bool IsTradingTimeAllowed() {
   if(!EnableTimeFilter) return true;
   MqlDateTime dt;
   TimeLocal(dt);
   int hour = dt.hour;
   int dow  = dt.day_of_week;
   if(dow >= 1 && dow <= 4)
      return (hour >= TradingStartHour || hour < TradingEndHour);
   if(dow == 5) {
      if(StopFridayAfterClose) return (hour >= TradingStartHour && hour < FridayCloseHour);
      return (hour >= TradingStartHour || hour < TradingEndHour);
   }
   return false;
}

bool IsMinHoldPassed(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return true;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   return (Bars(_Symbol, PERIOD_M5, openTime, TimeCurrent()) >= InpMinHoldBars);
}

//+------------------------------------------------------------------+
//  DD
//+------------------------------------------------------------------+
bool CheckEquityStop() {
   if(!InpEnableEquityStop) return false;
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal <= 0) return false;
   double dd = (bal - equity) / bal * 100.0;

   // Soft Brake: ถ้า DD > InpCompoundDDSoftBrake ใน Compound mode -> ลด lot กลับ Fixed ชั่วคราว
   if(currentLotMode == LOT_COMPOUND && InpEnableHouseMoney) {
      if(dd >= InpCompoundDDSoftBrake && !compoundBrake) {
         compoundBrake = true;
         Print("[COMPOUND BRAKE] DD=", DoubleToString(dd,2), "% >= SoftBrake=",
               InpCompoundDDSoftBrake, "% -> Lot capped to Fixed temporarily");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD COMPOUND BRAKE ON | DD=" + DoubleToString(dd,2)
                         + "% | Lot=FIXED until DD recovers | Balance $" + DoubleToString(bal,2));
      } else if(dd < InpCompoundDDSoftBrake * 0.75 && compoundBrake) {
         // ปลด brake เมื่อ DD ฟื้นกลับมา 75% ของ SoftBrake threshold
         compoundBrake = false;
         Print("[COMPOUND BRAKE] Released at DD=", DoubleToString(dd,2), "%");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD COMPOUND BRAKE OFF | DD=" + DoubleToString(dd,2)
                         + "% | Lot=COMPOUND restored | Balance $" + DoubleToString(bal,2));
      }
      // Kill Switch Compound: ใช้ InpCompoundMaxDD (กว้างกว่า)
      if(dd >= InpCompoundMaxDD) {
         Print("[KILL COMPOUND] DD=", DoubleToString(dd,2), "% >= ", InpCompoundMaxDD, "%");
         CloseAll("Kill Switch COMPOUND DD=" + DoubleToString(dd,2) + "%");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD KILL SWITCH COMPOUND | DD=" + DoubleToString(dd,2)
                         + "% | Balance $" + DoubleToString(bal,2)
                         + " | EA REMOVED from " + _Symbol);
         ExpertRemove();
         return true;
      }
   } else {
      // Fixed mode: ใช้ InpMaxDrawdownPercent ปกติ
      if(dd >= InpMaxDrawdownPercent) {
         Print("[KILL] DD=", DoubleToString(dd,2), "% >= ", InpMaxDrawdownPercent, "%");
         CloseAll("Kill Switch DD=" + DoubleToString(dd,2) + "%");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD KILL SWITCH | DD=" + DoubleToString(dd,2)
                         + "% | Balance $" + DoubleToString(bal,2)
                         + " | EA REMOVED from " + _Symbol);
         ExpertRemove();
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//  DAILY LOSS
//+------------------------------------------------------------------+
void UpdateDailyLoss() {
   datetime today = TimeCurrent() / 86400 * 86400;
   if(today != currentDay) {
      currentDay       = today;
      dayStartBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
      dayLowestEquity  = dayStartBalance;
      dailyLossPercent = 0.0;
      dailyLossClosed  = false;
      partialDone      = false;
      partialDoneSell  = false;
   }
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity < dayLowestEquity) {
      dayLowestEquity  = equity;
      dailyLossPercent = (dayStartBalance > 0)
                         ? (dayStartBalance - dayLowestEquity) / dayStartBalance * 100.0
                         : 0.0;
   }
}

bool IsDailyLossExceeded() {
   if(!EnableDailyLossLimit) return false;
   return (dailyLossPercent >= MaxDailyLossPercent);
}

//+------------------------------------------------------------------+
//  ALERTS
//+------------------------------------------------------------------+
void CheckDDAlert() {
   if(!InpEnableTelegram) return;
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal <= 0) return;
   double dd = (bal - equity) / bal * 100.0;
   if(dd < InpTelegramDDAlert) { ddAlertSent = false; return; }
   datetime now = TimeCurrent();
   if(ddAlertSent && (now - lastDDAlertTime) < 3600) return;
   TelegramSend("9AU_GOLD DD Alert " + DoubleToString(dd,2)
                + "% | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED")
                + " | Equity $" + DoubleToString(equity,2));
   ddAlertSent     = true;
   lastDDAlertTime = now;
}

void Check2xBalance() {
   if(!InpEnable2xAlert || !InpEnableTelegram) return;
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   int    cur2x = (int)MathFloor(bal / InpBaseBalance);
   if(cur2x <= last2xLevel) return;
   last2xLevel = cur2x;
   TelegramSend("MILESTONE 9AU_GOLD | Balance $" + DoubleToString(bal,2)
                + " (" + IntegerToString(cur2x) + "x BaseBalance)"
                + " | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
}

//+------------------------------------------------------------------+
//  INDICATORS
//+------------------------------------------------------------------+
double GetRSI() {
   double buf[1];
   int h = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 50.0;
   if(CopyBuffer(h, 0, 0, 1, buf) > 0) return buf[0];
   return 50.0;
}

double GetATR() {
   double buf[1];
   int h = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(h == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(h, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetEMA(int period = 200, int shift = 0) {
   double buf[1];
   int h = iMA(_Symbol, InpFilterTF, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(h, 0, shift, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetADX() {
   double buf[1];
   int h = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   if(h == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(h, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//  SELL REGIME
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Average ATR (baseline volatility over InpAvgATRPeriod bars)
double GetAvgATR() {
   double buf[];
   int h = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(h == INVALID_HANDLE) return 0.0;
   ArrayResize(buf, InpAvgATRPeriod);
   if(CopyBuffer(h, 0, 0, InpAvgATRPeriod, buf) < InpAvgATRPeriod) return 0.0;
   double sum = 0;
   for(int i = 0; i < InpAvgATRPeriod; i++) sum += buf[i];
   return sum / InpAvgATRPeriod;
}

// Resistance level = highest high over InpResistLookback M5 bars
double GetResistanceLevel() {
   double hi[];
   ArrayResize(hi, InpResistLookback);
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, InpResistLookback, hi) < InpResistLookback) return 0.0;
   double highest = hi[0];
   for(int i = 1; i < InpResistLookback; i++)
      if(hi[i] > highest) highest = hi[i];
   return highest;
}

bool IsTrendDown(double atr, double closePrice) {
   double adx     = GetADX();
   double ema200  = GetEMA(InpTrendEMA, 0);
   double ema200p = GetEMA(InpTrendEMA, InpEMASlopeLookback);
   double ema50   = GetEMA(InpEMA50Period, 0);
   double slope   = ema200 - ema200p;
   double rsi     = GetRSI();
   // Layer 3: ATR volatility filter - Sell only in volatile market
   double avgATR    = GetAvgATR();
   bool   atrOk     = (avgATR > 0) && (atr >= avgATR * InpSellMinATRMult);

   // Layer 4: Resistance filter - price must be below recent swing high - buffer
   double resist    = GetResistanceLevel();
   bool   resistOk  = (resist > 0) && (closePrice < resist * (1.0 - InpResistBuffer));

   // EMA50<200 เป็น bonus score ไม่ใช่ hard requirement -- Gold ช่วง uptrend EMA50 > EMA200 เสมอ
   // ถ้าทั้ง slope + price < EMA200 + ATR volatile + below resistance ก็เพียงพอสำหรับ Sell
   bool ema50Bearish = (ema50 < ema200);   // ideal แต่ไม่ required
   bool ok = (adx > InpADXTrendHigh)
             && (slope < -(atr * InpEMASlopeATRMult))
             && (closePrice < ema200)
             && (rsi >= InpRSITrendLow && rsi <= InpRSITrendHigh)
             && atrOk      // Layer 3: volatile market
             && resistOk   // Layer 4: below resistance
             && (ema50Bearish || (adx > InpADXTrendHigh * 1.5));  // EMA50 bearish OR very strong ADX

   if(InpDiagnosticLog)
      Print("[SELL REGIME] ADX=", DoubleToString(adx,1),
            " Slope=", DoubleToString(slope,2),
            " EMA50<200=", (ema50<ema200),
            " RSI=", DoubleToString(rsi,1),
            " ATR=", DoubleToString(atr,2), "/AvgATR=", DoubleToString(avgATR,2),
            " ATR_OK=", atrOk,
            " Resist=", DoubleToString(resist,2), " ResistOK=", resistOk,
            " -> ", ok ? "TREND_DOWN" : "no");
   return ok;
}

//+------------------------------------------------------------------+
//  BASKET
//+------------------------------------------------------------------+
void UpdateBasketInfo() {
   basket.buyCount = basket.sellCount = 0;
   basket.totalProfit = basket.totalLots = 0;
   basket.lastBuyPrice = basket.lastSellPrice = 0;
   basket.lastBuyLot   = basket.lastSellLot   = 0;
   basket.oldestOpenTime = TimeCurrent() + 86400*365;
   buyBasketProfit  = 0.0;
   sellBasketProfit = 0.0;
   datetime oldest  = TimeCurrent() + 86400*365;

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      double lot    = PositionGetDouble(POSITION_VOLUME);
      double price  = PositionGetDouble(POSITION_PRICE_OPEN);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime oT   = (datetime)PositionGetInteger(POSITION_TIME);
      basket.totalProfit += profit;
      basket.totalLots   += lot;
      if(oT < oldest) oldest = oT;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         basket.buyCount++;
         basket.lastBuyLot   = lot;
         basket.lastBuyPrice = price;
         buyBasketProfit    += profit;
      } else {
         basket.sellCount++;
         basket.lastSellLot   = lot;
         basket.lastSellPrice = price;
         sellBasketProfit    += profit;
      }
   }
   basket.oldestOpenTime = (basket.buyCount+basket.sellCount > 0) ? oldest : 0;
}

//+------------------------------------------------------------------+
//  LOT
//+------------------------------------------------------------------+
double CalculateSmartLot(int count, double lastLot,
                          double baseM, double redStep, double minM) {
   double m   = baseM - (count * redStep);
   if(m < minM) m = minM;
   double lot  = NormalizeDouble(lastLot * m, 2);
   double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(stp > 0) lot = MathRound(lot / stp) * stp;
   lot = MathMax(lot, minL);
   lot = MathMin(lot, maxL);
   return lot;
}

//+------------------------------------------------------------------+
//  EXPOSURE
//+------------------------------------------------------------------+
bool IsExposureSafe() {
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(ml <= 0) return true;
   if(ml < InpMinMarginLevel) { Print("[SKIP BUY] Margin Level=", DoubleToString(ml,2)); return false; }
   return true;
}

bool IsExposureSafeSell() {
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(ml <= 0) return true;
   if(ml < InpMinMarginLevel) { Print("[SKIP SELL] Margin Level=", DoubleToString(ml,2)); return false; }
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxExp = bal * (InpMaxExposurePercent * 0.5) / 100.0;
   double cSz    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double bidPx  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sellLots = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         sellLots += PositionGetDouble(POSITION_VOLUME);
   }
   if(sellLots * cSz * bidPx > maxExp) { Print("[SKIP SELL] Sell exposure exceeded"); return false; }
   return true;
}

//+------------------------------------------------------------------+
//  SL / TRAIL
//+------------------------------------------------------------------+
void SetHardSL(ulong ticket, double atr, double mult) {
   if(!PositionSelectByTicket(ticket)) return;
   double curSL  = PositionGetDouble(POSITION_SL);
   double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double dist = atr * mult;
   if(ptype == POSITION_TYPE_BUY) {
      double newSL = NormalizeDouble(openPx - dist, _Digits);
      if(curSL == 0 || newSL > curSL) {
         trade.PositionModify(ticket, newSL, 0);
         Print("[SL BUY] Ticket=", ticket, " SL=", DoubleToString(newSL,_Digits));
      }
   } else {
      double newSL = NormalizeDouble(openPx + dist, _Digits);
      if(curSL == 0 || newSL < curSL) {
         trade.PositionModify(ticket, newSL, 0);
         Print("[SL SELL] Ticket=", ticket, " SL=", DoubleToString(newSL,_Digits));
      }
   }
}

void ApplyHardSLAll(double atr) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetDouble(POSITION_SL) != 0) continue;
      double mult = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                    ? InpHardSLMultiplier : InpSellHardSLMultiplier;
      SetHardSL(t, atr, mult);
   }
}

void TrailBasket(double atr) {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Buy trail
   if(basket.totalProfit >= InpTrailStartUSD) {
      double dist = atr * InpTrailStepATR;
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
         if(!IsMinHoldPassed(t)) continue;
         double curSL = PositionGetDouble(POSITION_SL);
         double newSL = NormalizeDouble(bid - dist, _Digits);
         if(newSL > curSL) trade.PositionModify(t, newSL, 0);
      }
   }

   // Sell trail (tighter)
   if(sellBasketProfit >= InpSellTrailStartUSD) {
      double dist = atr * InpSellTrailStepATR;
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
         if(!IsMinHoldPassed(t)) continue;
         double curSL = PositionGetDouble(POSITION_SL);
         double newSL = NormalizeDouble(ask + dist, _Digits);
         if(curSL == 0 || newSL < curSL) trade.PositionModify(t, newSL, 0);
      }
   }
}

//+------------------------------------------------------------------+
//  BASKET CLOSE
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
      TelegramSend("9AU_GOLD CLOSE ALL | " + reason
                   + " | Balance $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
}

void CloseAllBuy(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      trade.PositionClose(t);
   }
   Print("=== CLOSE BUY: ", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD BUY CLOSED | " + reason
                   + " | Balance $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
}

void CloseAllSell(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      trade.PositionClose(t);
   }
   Print("=== CLOSE SELL: ", reason, " ===");
}

void PartialCloseBasket() {
   if(!InpEnablePartialClose || partialDone) return;
   if(basket.totalProfit < InpBasketTP * InpPartialCloseLevel) return;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / stp) * stp;
      if(half >= minL) trade.PositionClosePartial(t, half);
   }
   partialDone = true;
   Print("[PARTIAL BUY] Done at ", DoubleToString(InpPartialCloseLevel*100,0), "% of TP");
}

void PartialCloseBasketSell() {
   if(!InpEnablePartialClose || partialDoneSell) return;
   if(sellBasketProfit < InpSellBasketTP * InpPartialCloseLevel) return;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / stp) * stp;
      if(half >= minL) trade.PositionClosePartial(t, half);
   }
   partialDoneSell = true;
}

//+------------------------------------------------------------------+
//  TIME EXIT & NEWS
//+------------------------------------------------------------------+
void CheckTimeExit() {
   if(basket.oldestOpenTime == 0) return;
   if(TimeCurrent() - basket.oldestOpenTime > InpMaxHoldDays * 86400)
      CloseAll("MaxHoldDays exceeded");
}

void UpdateNewsCalendar() {
   datetime from = TimeCurrent();
   ArrayFree(TodayEvents);
   CalendarValueHistory(TodayEvents, from, from + 86400*3);
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
      datetime et = TodayEvents[i].time;
      if(now >= et - NewsBeforeMinutes*60 && now <= et + NewsAfterMinutes*60) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//  OnTick
//+------------------------------------------------------------------+
void OnTick() {
   // --- Kill Switch (every tick) ---
   if(CheckEquityStop()) return;

   // --- House Money check (every tick) ---
   CheckHouseMoney();

   // --- Daily management ---
   UpdateDailyLoss();
   CheckDDAlert();
   Check2xBalance();

   // --- Daily Loss CloseAll ---
   // Daily Loss CloseAll - ใช้ limit แคบกว่าใน Compound mode เพื่อปกป้อง HWM
   double closeAllLimit = (currentLotMode == LOT_COMPOUND)
                          ? InpCompoundDailyLossClose
                          : InpDailyLossCloseAllPercent;
   if(EnableDailyLossLimit && !dailyLossClosed && dailyLossPercent >= closeAllLimit) {
      CloseAll("Daily Loss CloseAll " + DoubleToString(dailyLossPercent,2)
               + "% [" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED") + "]");
      dailyLossClosed = true;
      TelegramSend("9AU_GOLD DAILY LOSS CLOSE ALL | " + DoubleToString(dailyLossPercent,2)
                   + "% | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
      return;
   }

   // --- New bar only ---
   if(!IsNewBar()) return;

   // --- Pre-trade filters ---
   if(EnableTimeFilter && !IsTradingTimeAllowed()) return;
   if(EnableNewsFilter && TimeCurrent() - lastNewsUpdate > 3600) UpdateNewsCalendar();
   if(IsNewsWindowActive()) return;

   double atrVal = GetATR();
   if(atrVal < InpMinATRThreshold) return;

   long   spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double maxSpread = (atrVal > 100) ? InpMaxSpreadHighVol : InpMaxSpreadBase;
   if(spreadPts > maxSpread) return;

   double rsiVal    = GetRSI();
   double emaVal    = GetEMA(InpTrendEMA, 0);
   double closeBar1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stp       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   UpdateBasketInfo();
   CheckTimeExit();
   ApplyHardSLAll(atrVal);
   TrailBasket(atrVal);

   // ============================================================
   //  BUY BASKET - original v14 logic + Compound Lot
   // ============================================================
   if(rsiVal < InpRSILowerLevel && closeBar1 > emaVal) {
      PartialCloseBasket();
      if(basket.buyCount > 0 && basket.totalProfit >= InpBasketTP) {
         CloseAllBuy("Buy TP=" + DoubleToString(InpBasketTP,2));
         partialDone = false;
         return;
      }

      if(IsDailyLossExceeded()) return;

      double dynDist = InpEnableDynamicGrid
                       ? MathMax(atrVal * InpATRMultiplier, 300.0 * _Point)
                       : 300.0 * _Point;

      if(basket.buyCount == 0) {
         if(IsExposureSafe()) {
            double lot = GetSniperLot();   // Fixed or Compound
            if(stp > 0) lot = MathRound(lot / stp) * stp;
            lot = MathMax(lot, minLot);
            if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_LEADER_GOLD")) {
               Print("[BUY] Sniper Lot=", DoubleToString(lot,2),
                     " Mode=", (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
               ulong tk = trade.ResultOrder();
               if(tk > 0) SetHardSL(tk, atrVal, InpHardSLMultiplier);
            }
         }
      } else if(basket.buyCount < InpMaxOrders) {
         if(ask < basket.lastBuyPrice - dynDist) {
            if(IsExposureSafe()) {
               double lot = CalculateSmartLot(basket.buyCount, basket.lastBuyLot,
                                               InpBaseMultiplier, InpReductionStep, InpMinMultiplier);
               if(stp > 0) lot = MathRound(lot / stp) * stp;
               lot = MathMax(lot, minLot);
               if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_LEADER_GOLD")) {
                  Print("[BUY] Grid #", basket.buyCount+1, " Lot=", DoubleToString(lot,2));
                  ulong tk = trade.ResultOrder();
                  if(tk > 0) SetHardSL(tk, atrVal, InpHardSLMultiplier);
               }
            }
         }
      }
   }

   // ============================================================
   //  SELL BASKET - TREND_DOWN Regime + Compound Lot
   // ============================================================
   if(!InpEnableSell) return;
   if(basket.buyCount > 0) return;

   if(IsTrendDown(atrVal, closeBar1)) {
      PartialCloseBasketSell();
      if(basket.sellCount > 0 && sellBasketProfit >= InpSellBasketTP) {
         CloseAllSell("Sell TP=" + DoubleToString(InpSellBasketTP,2));
         partialDoneSell = false;
         return;
      }

      if(IsDailyLossExceeded()) return;

      double sellDist = InpEnableDynamicGrid
                        ? MathMax(atrVal * InpSellATRMultiplier, 450.0 * _Point)
                        : 450.0 * _Point;

      if(basket.sellCount == 0) {
         if(IsExposureSafeSell()) {
            double lot = GetSellSniperLot();   // Fixed or Compound
            if(stp > 0) lot = MathRound(lot / stp) * stp;
            lot = MathMax(lot, minLot);
            if(trade.Sell(lot, _Symbol, bid, 0, 0, "9AU_LEADER_GOLD_S")) {
               Print("[SELL] Sniper Lot=", DoubleToString(lot,2),
                     " Mode=", (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
               ulong tk = trade.ResultOrder();
               if(tk > 0) SetHardSL(tk, atrVal, InpSellHardSLMultiplier);
            }
         }
      } else if(basket.sellCount < InpSellMaxOrders) {
         if(bid > basket.lastSellPrice + sellDist) {
            if(IsExposureSafeSell()) {
               double lot = CalculateSmartLot(basket.sellCount, basket.lastSellLot,
                                               InpSellBaseMultiplier, InpSellReductionStep, InpSellMinMultiplier);
               if(stp > 0) lot = MathRound(lot / stp) * stp;
               lot = MathMax(lot, minLot);
               if(trade.Sell(lot, _Symbol, bid, 0, 0, "9AU_LEADER_GOLD_S")) {
                  Print("[SELL] Grid #", basket.sellCount+1, " Lot=", DoubleToString(lot,2));
                  ulong tk = trade.ResultOrder();
                  if(tk > 0) SetHardSL(tk, atrVal, InpSellHardSLMultiplier);
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
