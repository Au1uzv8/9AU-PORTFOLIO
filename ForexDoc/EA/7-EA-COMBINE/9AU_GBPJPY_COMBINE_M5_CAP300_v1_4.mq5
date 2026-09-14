//+------------------------------------------------------------------+
//|     9AU_GBPJPY_COMBINE_M5_CAP300.mq5                              |
//|     James Consultant | RSI Rebound + EMA Pullback + ADX          |
//|     Long-Only Basket Grid with Cut Loss / Depth Limiter          |
//|  v1.1: Virtual Balance/Equity per Magic - รองรับรันร่วมบัญชี     |
//|        กับ EA อื่นใน Port เดียวกัน (Port-Combine)                |
//|  v1.2: เพิ่ม Compound Selective (Auto Dynamic Lot 1.5x) - sync   |
//|        กับแผนใหม่ของ AUDCAD/3PAIRS/OIL/NDAQ100                   |
//|  v1.3: เพิ่ม SoftBrake (DD>=15% Brake / DD>=22% Kill) concept    |
//|        เดียวกับ OIL-WTI/GOLD ทุกจุด — Compound Active ถาวรเมื่อ  |
//|        Trigger แล้ว คุมความเสี่ยงด้วย Brake แทน Deactivate       |
//|  v1.4: เพิ่ม InpDCAtoAdd (Manual DCA, Cumulative Total) +        |
//|        Global Variable Delta Guard + On-Chart Label              |
//+------------------------------------------------------------------+
#property copyright "9Au & James Consultant - R300"
#property version   "1.4"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input int      InpMagicNumber      = 515254;

input group "=== Step A: Filter ==="
input int              InpTrendEMA       = 200;      // Trend EMA period on H1
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_H1;
input int              InpRSIPeriod      = 14;
input double           InpRSIUpperLevel  = 58.0;     // Not used for buy (kept for legacy)
input double           InpRSILowerLevel  = 30.0;     // Not used directly now (kept for legacy)
input double           InpRSIBuyZoneHigh = 50.0;     // Buy only if M5 RSI < this level (prevent overbought)

input group "=== Silver RSI Pro Filter ==="
input int    InpRSIPeriodH1      = 14;
input double InpRSILowerLevelH1  = 50.0;             // Not used now
input double InpRSIUpperLevelH1  = 55.0;             // Max H1 RSI allowed to enter buy (avoid overbought in higher TF)
input bool   InpUseDualTF        = true;

input group "=== Trend Strength (ADX) ==="
input int    InpADXPeriod        = 14;
input double InpADXMin           = 28.0;             // Sweet Spot Minimum ADX to ensure trend strength

input group "=== Step B: Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 4.5;            // Sweet Spot Grid distance in ATR (slightly wider)
input double InpInitialLot         = 0.01;
input double InpBaseMultiplier     = 1.12;
input double InpReductionStep      = 0.03;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 4;

input group "=== Step C: Profit & Exit ==="
input double InpBasketTP           = 22.0;           // Take profit for whole basket
input double InpBasketCutLoss      = 40.0;           // Cut loss for basket
input double InpMaxGridDepthATR    = 4.0;            // Sweet Spot Max allowed grid depth in ATR
input bool   InpEnablePartialClose = true;
input double InpPartialCloseLevel  = 0.70;           // Partial close at 70% of TP
input double InpHardSLMultiplier   = 8.0;            // Hard stop loss distance in ATR
input int    InpMinHoldBars        = 20;             // Minimum bars before trailing/partial

input group "=== Step D: News Filter ==="
input bool   EnableNewsFilter      = true;
input int    NewsBeforeMinutes     = 60;
input int    NewsAfterMinutes      = 60;
input bool   NewsHighImpactOnly    = true;

input group "=== Step E: Safety & Protection ==="
input bool   InpEnableEquityStop   = true;
input double InpMaxDrawdownPercent = 25.0;
input double InpTrailStartUSD      = 15.0;
input double InpTrailStepATR       = 1.5;
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 0.02;
input double InpMaxSpreadBase      = 210.0;
input double InpMaxSpreadHighVol   = 290.0;
input double InpMinMarginLevel      = 700.0;

input group "=== Step F: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 8;
input int    TradingEndHour        = 23;
input bool   StopFridayAfterClose  = true;
input int    FridayCloseHour       = 18;

input group "=== Step G: Floating Drawdown Limit ==="
input bool   InpEnableFloatingDD   = false;
input double InpMaxFloatingDDPercent = 5.0;

input group "=== Step H: Telegram Notify ==="
input bool   InpEnableTelegram     = true;
input string InpToken              = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID             = "8053031320";
input double InpTelegramDDAlert    = 15.0;
input bool   InpEnable2xAlert      = true;
input double InpBaseBalance        = 300.0;

input group "=== Step I: Compound Selective (Auto Dynamic Lot 1.5x + SoftBrake) ==="
input bool   InpUseCompound         = true;   // เปิด Auto Dynamic Lot ตามแผนใหม่
input double InpCompoundStartMult   = 1.5;    // เริ่ม Compound เมื่อ Virtual Balance >= BaseBalance x 1.5
input double InpCompoundDDSoftBrake = 15.0;   // DD (จาก Compound HWM) >= 15% -> Brake กลับ Fixed ชั่วคราว
input double InpCompoundMaxDD       = 22.0;   // DD (จาก Compound HWM) >= 22% -> Kill Switch (CloseAll+ExpertRemove)

input group "=== Step J: Manual DCA (Cumulative Total, ไม่ใช่ยอดต่อเดือน) ==="
input double InpDCAtoAdd            = 0.0;    // กรอกเป็นยอด DCA สะสมทั้งหมดตั้งแต่เริ่ม (เดือน1=25, เดือน2=50 ...)

//+------------------------------------------------------------------+
//| Global Structures & Variables                                    |
//+------------------------------------------------------------------+
struct BasketInfo {
   int      buyCount;
   int      sellCount;
   double   totalProfit;
   double   totalLots;
   double   lastBuyPrice;    // most recently opened buy (latest open time)
   double   lowestBuyPrice;  // lowest open price among all buys (grid reference)
   double   lastSellPrice;
   double   lastBuyLot;
   double   lastSellLot;
   double   oldestBuyPrice;
   datetime oldestOpenTime;
};
BasketInfo basket;

datetime currentDay      = 0;
double   floatingDD      = 0.0;
bool     partialDone     = false;

int      handleRSI_M5, handleRSI_H1, handleADX, handleTrendMA, handleATR;
MqlCalendarValue todayEvents[];
datetime lastNewsUpdate = 0;

// --- Virtual Balance/Equity per Magic Number (Port-Combine) ---
double   vRealizedProfit = 0.0;
bool     g_compoundActive = false;   // Auto Dynamic Lot 1.5x — Active flag (permanent เมื่อ Trigger แล้ว เหมือน OIL/GOLD)
bool     g_compoundBrake  = false;   // SoftBrake — true เมื่อ DD จาก Compound HWM >= SoftBrake threshold
double   g_compoundHWM    = 0.0;     // High Water Mark ของ Virtual Equity นับจากวินาทีที่ Compound Active

//+------------------------------------------------------------------+
//  VIRTUAL BALANCE / EQUITY (per Magic Number)
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
//| MANUAL DCA — Cumulative Total + Global Variable Delta Guard        |
//| (Pattern เดียวกับ Gold/OIL-WTI/USDJPY/AUDCAD/3PAIRS)               |
//+------------------------------------------------------------------+
string GVName_DCA() { return "9AU_DCA_APPLIED_" + IntegerToString(InpMagicNumber); }

void ApplyDCAIfNeeded() {
   string gv = GVName_DCA();
   double lastApplied = GlobalVariableCheck(gv) ? GlobalVariableGet(gv) : 0.0;
   double delta = InpDCAtoAdd - lastApplied;
   if(MathAbs(delta) < 0.01) return;

   vRealizedProfit += delta;
   GlobalVariableSet(gv, InpDCAtoAdd);
   Print("[DCA] GBPJPY Applied Delta=$", DoubleToString(delta,2),
         " | Cumulative Target=$", DoubleToString(InpDCAtoAdd,2),
         " | New VBal=$", DoubleToString(GetVirtualBalance(),2));
   if(InpEnableTelegram)
      TelegramSend("9AU_GBPJPY DCA APPLIED | Delta=$" + DoubleToString(delta,2)
                   + " | Cumulative=$" + DoubleToString(InpDCAtoAdd,2)
                   + " | New VBal=$" + DoubleToString(GetVirtualBalance(),2));
}

void DrawDCALabel() {
   string name = "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber);
   double applied = GlobalVariableCheck(GVName_DCA()) ? GlobalVariableGet(GVName_DCA()) : 0.0;
   string txt = StringFormat("GBPJPY(%d) DCA Cumulative=$%.2f | VBase=$%.2f | VBal=$%.2f",
                              InpMagicNumber, applied, InpBaseBalance, GetVirtualBalance());
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 40);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

//+------------------------------------------------------------------+
//| Auto Dynamic Lot 1.5x — Compound Selective (sync กับ AUDCAD/3PAIRS/OIL)|
//| Active แบบถาวรเมื่อ Virtual Balance >= BaseBalance x StartMult     |
//| (ไม่ Deactivate กลับ — คุมความเสี่ยงด้วย SoftBrake/Kill แทน         |
//| Concept เดียวกับ OIL-WTI/GOLD ทุกจุด)                              |
//+------------------------------------------------------------------+
void UpdateCompoundState() {
   if(!InpUseCompound) return;

   double vBal = GetVirtualBalance();
   double vEq  = GetVirtualEquity();

   // Activate Compound เมื่อ balance ถึง threshold (ครั้งเดียว ถาวร)
   if(!g_compoundActive && vBal >= InpBaseBalance * InpCompoundStartMult) {
      g_compoundActive = true;
      g_compoundHWM    = vEq;
      TelegramSend("9AU_GBPJPY COMPOUND ACTIVATED | Bal=" + DoubleToString(vBal,2) + " | Lot scaling ON");
      Print("[Compound] GBPJPY ACTIVATED | VBal=", DoubleToString(vBal,2));
   }

   if(!g_compoundActive) return;

   // อัพเดต Compound HWM
   if(vEq > g_compoundHWM) g_compoundHWM = vEq;

   // คำนวณ Compound DD จาก g_compoundHWM
   double cDD = (g_compoundHWM > 0) ? (g_compoundHWM - vEq) / g_compoundHWM * 100.0 : 0.0;

   // SoftBrake ON
   if(!g_compoundBrake && cDD >= InpCompoundDDSoftBrake) {
      g_compoundBrake = true;
      TelegramSend("9AU_GBPJPY COMPOUND BRAKE ON | DD=" + DoubleToString(cDD,2) + "% -> Lot Fixed ชั่วคราว");
      Print("[Compound Brake] GBPJPY ON. DD=", cDD);
   }

   // SoftBrake OFF เมื่อ DD ฟื้นกลับ 75% ของ SoftBrake threshold
   if(g_compoundBrake && cDD < InpCompoundDDSoftBrake * 0.75) {
      g_compoundBrake = false;
      TelegramSend("9AU_GBPJPY COMPOUND BRAKE OFF | DD=" + DoubleToString(cDD,2) + "% -> Lot Compound กลับมา");
      Print("[Compound Brake] GBPJPY OFF. DD=", cDD);
   }

   // Kill Switch Compound
   if(cDD >= InpCompoundMaxDD) {
      TelegramSend("9AU_GBPJPY COMPOUND KILL | DD=" + DoubleToString(cDD,2) + "% >= " +
                   DoubleToString(InpCompoundMaxDD,0) + "% | CloseAll");
      CloseAll("COMPOUND KILL SWITCH");
      ExpertRemove();
   }
}

double GetCompoundLot(double base_lot) {
   if(!g_compoundActive || g_compoundBrake) return base_lot;
   double vEq  = GetVirtualEquity();
   double lot  = NormalizeDouble(base_lot * (vEq / InpBaseBalance), 2);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lot = MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   return lot;
}

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
double GetATR() {
   double buf[1];
   if(CopyBuffer(handleATR, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetRSI_M5(int shift = 0) {
   double buf[1];
   if(CopyBuffer(handleRSI_M5, 0, shift, 1, buf) > 0) return buf[0];
   return -1;
}

double GetRSI_H1(int shift = 0) {
   double buf[1];
   if(CopyBuffer(handleRSI_H1, 0, shift, 1, buf) > 0) return buf[0];
   return -1;
}

double GetADX() {
   double buf[1];
   if(CopyBuffer(handleADX, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetTrendMA(int shift = 0) {
   double buf[1];
   if(CopyBuffer(handleTrendMA, 0, shift, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
void UpdateBasketInfo() {
   basket.buyCount       = 0;
   basket.sellCount      = 0;
   basket.totalProfit    = 0.0;
   basket.totalLots      = 0.0;
   basket.lastBuyPrice   = 0.0;
   basket.lowestBuyPrice = 0.0;
   basket.lastSellPrice  = 0.0;
   basket.lastBuyLot     = 0.0;
   basket.lastSellLot    = 0.0;
   basket.oldestBuyPrice = 0.0;
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

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         basket.buyCount++;
         // lowestBuyPrice = deepest grid leg (reference for next grid distance)
         if(basket.lowestBuyPrice == 0.0 || price < basket.lowestBuyPrice)
            basket.lowestBuyPrice = price;
         // lastBuyLot = lot of the most recently opened buy leg (for compound calc)
         if(basket.lastBuyPrice == 0.0 || openTime > (datetime)PositionGetInteger(POSITION_TIME))
            basket.lastBuyLot = lot;
         basket.lastBuyPrice = price;
         if(openTime < oldest) {
            oldest = openTime;
            basket.oldestBuyPrice = price;
         }
      } else {
         basket.sellCount++;
         basket.lastSellLot   = lot;
         basket.lastSellPrice = price;
      }
      if(openTime < oldest) oldest = openTime;
   }
   basket.oldestOpenTime = (basket.buyCount + basket.sellCount > 0) ? oldest : 0;
}

bool IsMinHoldPassed(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return true;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   return (Bars(_Symbol, PERIOD_M5, openTime, TimeCurrent()) >= InpMinHoldBars);
}

double CalculateSmartLot(int count, double lastLot) {
   double m = InpBaseMultiplier - count * InpReductionStep;
   if(m < InpMinMultiplier) m = InpMinMultiplier;
   double lot    = NormalizeDouble(lastLot * m, 2);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lot = MathMin(lot, maxLot);
   return lot;
}

void CloseAll(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         trade.PositionClose(t);
   }
   Print("CLOSE ALL: ", reason);
   if(InpEnableTelegram) TelegramSend("SNIPER CLOSE ALL: " + reason);
}

void SetHardSL(ulong ticket, double atr) {
   if(!PositionSelectByTicket(ticket)) return;
   double curSL = PositionGetDouble(POSITION_SL);
   double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
   double slDist = atr * InpHardSLMultiplier;
   double newSL = NormalizeDouble(openPx - slDist, _Digits);
   if(curSL == 0 || newSL > curSL) trade.PositionModify(ticket, newSL, 0);
}

void ApplyHardSLAll(double atr) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         if(PositionGetDouble(POSITION_SL) == 0) SetHardSL(t, atr);
   }
}

void PartialCloseBasket() {
   if(!InpEnablePartialClose || partialDone) return;
   if(basket.totalProfit < InpBasketTP * InpPartialCloseLevel) return;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double half = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / step) * step;
      if(half >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         trade.PositionClosePartial(t, half);
   }
   partialDone = true;
}

void TrailBasket(double atr) {
   if(basket.totalProfit < InpTrailStartUSD) return;
   double trailDist = atr * InpTrailStepATR;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t) || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsMinHoldPassed(t)) continue;
      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = NormalizeDouble(bid - trailDist, _Digits);
      if(newSL > curSL) trade.PositionModify(t, newSL, 0);
   }
}

//+------------------------------------------------------------------+
void UpdateNewsCalendar() {
   datetime now = TimeCurrent();
   if(now - lastNewsUpdate > 3600) {
      CalendarValueHistory(todayEvents, now, now + 86400 * 3);
      lastNewsUpdate = now;
   }
}

bool IsNewsWindowActive() {
   if(!EnableNewsFilter) return false;
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(todayEvents); i++) {
      MqlCalendarEvent   ev;
      MqlCalendarCountry cntry;
      if(!CalendarEventById(todayEvents[i].event_id, ev)) continue;
      if(!CalendarCountryById(ev.country_id, cntry)) continue;
      string cur = cntry.currency;
      if(cur != "USD" && cur != "GBP" && cur != "JPY") continue;
      if(NewsHighImpactOnly && ev.importance < 3) continue;
      datetime eventTime = todayEvents[i].time;
      if(now >= eventTime - NewsBeforeMinutes*60 && now <= eventTime + NewsAfterMinutes*60) {
         Print("[SKIP] News: ", ev.name);
         return true;
      }
   }
   return false;
}

bool IsTradingTime() {
   if(!EnableTimeFilter) return true;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   if(dt.day_of_week == 5 && StopFridayAfterClose && dt.hour >= FridayCloseHour) return false;
   return (dt.hour >= TradingStartHour && dt.hour < TradingEndHour);
}

bool IsNewBar() {
   static datetime lastBar = 0;
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t != lastBar) { lastBar = t; return true; }
   return false;
}

bool CheckEquityStop() {
   if(!InpEnableEquityStop) return false;
   double balance = GetVirtualBalance();
   double equity  = GetVirtualEquity();
   if(balance <= 0) return false;
   double dd = (balance - equity) / balance * 100.0;
   if(dd >= InpMaxDrawdownPercent) {
      CloseAll("Equity Stop DD=" + DoubleToString(dd,2) + "%");
      ExpertRemove();
      return true;
   }
   return false;
}

void UpdateFloatingDD() {
   datetime today = TimeCurrent() / 86400 * 86400;
   if(today != currentDay) {
      currentDay  = today;
      floatingDD   = 0.0;
      partialDone = false;
   }
   double eq = GetVirtualEquity();
   double bal = GetVirtualBalance();
   double loss = bal - eq;
   if(loss > floatingDD) floatingDD = loss;
}

bool IsFloatingDDExceeded() {
   if(!InpEnableFloatingDD) return false;
   double limit = GetVirtualBalance() * InpMaxFloatingDDPercent / 100.0;
   if(floatingDD >= limit) {
      Print("[SKIP] FloatingDD=", DoubleToString(floatingDD,2), " / Limit=", DoubleToString(limit,2));
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| New Entry Logic – RSI Rebound + Pullback + ADX (No lower-bound)  |
//+------------------------------------------------------------------+
bool IsBuySignal() {
   double rsi0 = GetRSI_M5(0);
   double rsi1 = GetRSI_M5(1);

   // 1. RSI must be rising and not already overbought
   if(rsi0 <= rsi1) return false;
   if(rsi0 > InpRSIBuyZoneHigh) return false;

   // 2. H1 RSI must not be too high (avoid buying into overbought higher TF)
   if(InpUseDualTF) {
      double rsiH1 = GetRSI_H1(0);
      if(rsiH1 > InpRSIUpperLevelH1) return false;
   }

   // 3. ADX check
   double adx = GetADX();
   if(adx < InpADXMin) return false;

   // 4. Price must be above EMA and within 2 ATR (pullback zone)
   double ema = GetTrendMA(0);
   double price = iClose(_Symbol, PERIOD_M5, 0);
   if(price < ema) return false;

   double atr = GetATR();
   if(atr > 0) {
      double distATR = (price - ema) / atr;
      if(distATR > 2.0) return false;   // too far above EMA, not a pullback
   }

   return true;
}

//+------------------------------------------------------------------+
//| Initialization                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   ScanInitialRealizedProfit();
   ApplyDCAIfNeeded();
   DrawDCALabel();

   handleRSI_M5  = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   handleRSI_H1  = iRSI(_Symbol, PERIOD_H1, InpRSIPeriodH1, PRICE_CLOSE);
   handleADX     = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   handleTrendMA = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleATR     = iATR(_Symbol, PERIOD_M5, InpATRPeriod);

   if(handleRSI_M5 == INVALID_HANDLE || handleRSI_H1 == INVALID_HANDLE ||
      handleADX == INVALID_HANDLE || handleTrendMA == INVALID_HANDLE ||
      handleATR == INVALID_HANDLE)
   {
      Print("Indicator creation failed");
      return INIT_FAILED;
   }

   Print("9AU SNIPER Loaded | RSI Rebound + EMA Pullback + ADX | Magic=", InpMagicNumber,
         " | EMA=", InpTrendEMA, " | ADX>=", InpADXMin,
         " | CutLoss=", InpBasketCutLoss, " TP=", InpBasketTP);
   if(InpEnableTelegram)
      TelegramSend("9AU SNIPER Started | " + _Symbol + " | Virtual Balance " + DoubleToString(GetVirtualBalance(),2));

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   IndicatorRelease(handleRSI_M5);
   IndicatorRelease(handleRSI_H1);
   IndicatorRelease(handleADX);
   IndicatorRelease(handleTrendMA);
   IndicatorRelease(handleATR);
   ObjectDelete(0, "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber));
}

//+------------------------------------------------------------------+
//| Main OnTick                                                      |
//+------------------------------------------------------------------+
void OnTick() {
   if(CheckEquityStop()) return;
   UpdateCompoundState();   // Auto Dynamic Lot 1.5x
   UpdateFloatingDD();
   if(IsFloatingDDExceeded()) return;

   UpdateBasketInfo();

   // --- Basket Cut Loss: every tick ---
   if(basket.buyCount > 0 && basket.totalProfit <= -InpBasketCutLoss) {
      CloseAll("Basket Cut Loss $" + DoubleToString(InpBasketCutLoss,2));
      partialDone = false;
      return;
   }

   // --- Cache ATR once per tick ---
   double atrVal = GetATR();

   // --- Grid Depth Limiter: every tick ---
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(basket.buyCount > 0 && basket.lowestBuyPrice > 0 && atrVal > 0) {
      double depthATR = (basket.lowestBuyPrice - bid) / atrVal;
      if(depthATR >= InpMaxGridDepthATR) {
         CloseAll("Grid Depth Exceeded " + DoubleToString(depthATR,1) + "x ATR");
         partialDone = false;
         return;
      }
   }

   // --- Grid Leg: every tick, price-distance only ---
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double dynamicDist = InpEnableDynamicGrid
                        ? MathMax(atrVal * InpATRMultiplier, 300.0 * _Point)
                        : 300.0 * _Point;

   if(basket.buyCount > 0 && basket.buyCount < InpMaxOrders
      && basket.sellCount == 0
      && ask < basket.lowestBuyPrice - dynamicDist  // use lowest grid leg as reference
      ) { // grid fires when price drops 1 full ATR*mult below lowest existing buy leg
      double lot = CalculateSmartLot(basket.buyCount, basket.lastBuyLot);
      if(trade.Buy(lot, _Symbol, ask, 0, 0, "SNIPER Grid")) {
         ulong ticket = trade.ResultOrder();
         if(ticket > 0) SetHardSL(ticket, atrVal);
         UpdateBasketInfo(); // refresh lowestBuyPrice immediately to prevent re-fire
         Print("[OPEN] Grid Buy #", basket.buyCount, " Lot=", DoubleToString(lot,2),
               " Dist=", DoubleToString(basket.lowestBuyPrice - ask, 3));
      }
   }

   // --- New bar actions: First Entry + Basket Management ---
   if(!IsNewBar()) return;
   if(!IsTradingTime()) return;
   UpdateNewsCalendar();
   if(IsNewsWindowActive()) return;

   if(atrVal < InpMinATRThreshold) {
      Print("[SKIP] ATR=", DoubleToString(atrVal,2), " < Min=", InpMinATRThreshold);
      return;
   }

   long   spreadPts      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double maxSpreadAllow = (atrVal > 0.20) ? InpMaxSpreadHighVol : InpMaxSpreadBase;
   if(spreadPts > maxSpreadAllow) {
      Print("[SKIP] Spread=", spreadPts, " > Max=", maxSpreadAllow);
      return;
   }

   // --- First Entry: full signal filter required ---
   if(IsBuySignal() && basket.sellCount == 0 && basket.buyCount == 0) {
      double lot = NormalizeDouble(GetCompoundLot(InpInitialLot), 2);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      lot = MathRound(lot / step) * step;
      lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
      if(trade.Buy(lot, _Symbol, ask, 0, 0, "Sniper")) {
         ulong ticket = trade.ResultOrder();
         if(ticket > 0) SetHardSL(ticket, atrVal);
         Print("[OPEN] Sniper Buy Lot=", DoubleToString(lot,2), " ATR=", DoubleToString(atrVal,2));
      }
   }

   // --- Basket Management: per bar ---
   if(basket.buyCount > 0) {
      ApplyHardSLAll(atrVal);
      TrailBasket(atrVal);
      PartialCloseBasket();
      if(basket.totalProfit >= InpBasketTP) {
         CloseAll("Basket TP=" + DoubleToString(InpBasketTP,2) + " Reached");
         partialDone = false;
      }
   }

   // --- Time Exit ---
   if(basket.oldestOpenTime > 0 && TimeCurrent() - basket.oldestOpenTime > InpMaxHoldDays * 86400)
      CloseAll("Time Exit: MaxHoldDays exceeded");
}
//+------------------------------------------------------------------+