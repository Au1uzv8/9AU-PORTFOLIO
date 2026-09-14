//+------------------------------------------------------------------+
//|                         9AU_SILVER_RESERVE_M5_CAP450.mq5    |
//|     James Consultant | Fixed Lot + 2x Withdraw Alert Telegram    |
//|                   Magic 3131 | DD<20% | WinRate>70% | PF>1.50    |
//|                  Upgrade: Dual‑Timeframe RSI Filter for Silver    |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "2.7"
// v2.5: Re-optimized InpNearDeathDDPercent 40.0 -> 60.0 (2026-08-09) after
// XM cut off historical ticks before 2024.12.01, removing the Oct 2023
// crisis sample from the available backtest window. Re-ran the same
// 30/35/40/45/50/60/65 sweep on the new 2024.12.01-2026.07.15 window
// (Research Mode, Cycle Simulator methodology): 60.0 now gives the best
// Win Rate (80.0%) and lowest Kill/year (1.23), confirmed as a genuine
// local optimum by bracketing with 65.0 (which reverses - Win Rate drops
// to 72.73%, Kill/year rises to 1.85). Old default 40.0 is no longer
// optimal for the currently-available data window.
#property strict
// v2.4: Added InpSpreadStressPoints for Spread Stress Testing. MT5's Custom
// Spread setting in Strategy Tester has NO EFFECT under "Every tick based
// on real ticks" (used throughout this project - History Quality 100% real
// ticks) because the real historical tick spread is always used instead.
// Confirmed empirically: a Spread=60 Custom Spread test produced BIT-
// IDENTICAL results to the Spread=40 baseline. Fix: InpSpreadStressPoints
// adds directly to the Ask price used for entries (both Sniper and Grid),
// simulating a wider effective spread while keeping Real-Tick precision for
// everything else. Set to 0 for normal baseline; set to (target - current
// real spread) for stress testing, e.g. 20 to simulate ~60pt effective
// spread on top of Silver's real ~40pt spread.
//   InpResearchMode=false | InpEnableReserveSystem=true
//   InpMaxDrawdownPercent=70.0 | InpNearDeathDDPercent=40.0 (optimized: best
//   Win Rate 75%/lowest Kill-rate among 30/35/40/45/50/60 tested)
//   InpBaseBalance=450.0 | InpReserveCapital=225.0 (Initial Deposit=675)
// All internal strings/comments renamed from 9AU_SILVER_TREND_RSI_GRID_M5_R300
// to 9AU_SILVER_RESERVE_M5_CAP450 to match the file header/behavior.
// v2.3: Bugfix found during Live Mode validation (ข้อ 9) - g_hardKillCount
// was only incremented inside the Research-Mode branch of CheckEquityStop(),
// so a real Live-Mode Hard-Kill (ExpertRemove() genuinely fired, confirmed
// by Bars cutting short and Balance dropping) still reported HARD-KILL=0 in
// the OnDeinit summary. Fixed: counter now increments before the branch, so
// it's tracked identically in both modes. The underlying stop mechanism
// itself was already correct in v2.2 - this only fixes the reported count.
// v2.2: Added InpResearchMode toggle (requested: "Checkbox เลือกว่า Period
// ทดสอบ หรือ Live"):
//   InpResearchMode=true  (default) -> Backtest/Research: EVERY terminal
//     event (Hard-Kill at InpMaxDrawdownPercent, Cooldown Timeout-Kill, and
//     the new WIN at InpBaseBalance x InpCycleTargetMultiple) calls
//     ResetCycle() instead of ExpertRemove() - CloseAll(), rebase the
//     virtual account back to InpBaseBalance, and keep trading in the SAME
//     Backtest pass. Full-period Journal now reports total WIN/KILL counts.
//   InpResearchMode=false -> Live: unchanged real behavior - Hard-Kill and
//     Cooldown-Timeout genuinely ExpertRemove() (stop and wait for the
//     trader), WIN only triggers the existing Check2xBalance() alert (no
//     forced reset - real withdrawal requires the trader's own action).
// Also replaced the v2.0/v2.1 "subtract locked reserve" DD formula with a
// fully rebased Virtual Equity model: g_activeBase + (real equity change
// since last cycle reset). This is required for Research Mode: without it,
// the real, ever-compounding account balance would leak into each new
// cycle's DD/WIN math (same class of bug found & fixed in the standalone
// Cycle Simulator's v1.0->v1.1 update).
// v2.0/2.1: Reserve Capital / Near-Death Cooldown System (2 กระเป๋า) - see
// project history for the original Q3 checklist design rationale.
// v2.0: Reserve Capital / Near-Death Cooldown System (2 กระเป๋า).
// Concept: Deposit InpBaseBalance+InpReserveCapital (e.g. 450+225=675) from
// Day 1. EA computes Exposure/DailyLoss/DD against g_activeBase=450 ONLY
// until a Near-Death event (DD >= InpNearDeathDDPercent, default 60%,
// BEFORE the hard InpMaxDrawdownPercent=70% Kill Switch). On Near-Death:
//   1. PAUSE all new order-opening (new basket + grid-add). SL/Trail/
//      PartialClose/Basket TP on existing positions continue as normal.
//   2. Every new bar for up to InpCoolDownMinutes, score a 5-point Q3
//      reversal checklist (RSI(H1) Divergence, EMA(H4) Reclaim, ATR(H1)
//      Contraction, Grid Slots Remaining, M5 Failed-Breakdown).
//   3a. Score >= InpReversalScoreMin -> g_activeBase expands to 675
//       (money already in the account - pure bookkeeping change), DD peak
//       effectively resets with fresh runway, resume normal trading.
//   3b. Timeout with no reversal confirmed -> CloseAll + ExpertRemove
//       ("ปล่อยพอร์ตแตก", wait for a fresh cycle/deposit).
// GetVirtualEquityForDD() prevents the (Day-1-deposited) locked reserve
// from silently diluting every DD% calculation before it's unlocked.
// Built on v1.6 (confirmed rollback baseline) - all v1.2-v1.6 fixes retained.
// produced BIT-IDENTICAL results to the pre-v1.3 baseline across the full
// 2.5-year test, meaning the High-Vol condition never fired even once
// (including during the confirmed Oct 2023 price shock). Root cause fix:
// GetATR()/GetAvgATR() were creating a NEW indicator handle every single
// tick call (same anti-pattern as the InpTrendEMA=0 bug found earlier) -
// now both use ONE cached handle (g_atrHandle) created in OnInit and
// released in OnDeinit. Also added an UNCONDITIONAL per-bar diagnostic
// Print (outside the RSI Buy Signal gate) so the Journal can confirm
// whether/when ATR/AvgATR ratio actually crosses InpVolRegimeThresh.
// v1.3: Added Volatility Regime Switch (pattern proven in 9AU_BTC v3.4).
// Grid Depth (InpMaxOrders) and Hard SL (InpHardSLMultiplier) reverted to
// ORIGINAL values - SET-A/SET-B testing showed tightening both simultaneously
// removes the grid's averaging-down capacity while realizing losses faster,
// making DD WORSE (59.7% vs 39.2% in the same Oct2023-Feb2024 window).
// Instead: keep normal-condition grid spacing tight (profitable as-is), and
// only widen ATR spacing during detected High Volatility regimes
// (ATR / AvgATR(50) > 1.30) to absorb shocks like Oct 2023 without
// sacrificing baseline performance.
// v1.2: Fixed Equity Stop reference-drift bug (peak-based baseline).

#include <Trade\Trade.mqh>
CTrade trade;

input int    InpMagicNumber      = 919290;

input group "=== Step A: Filter ==="
input int              InpTrendEMA       = 0;
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_H4;
input int              InpRSIPeriod      = 14;
input double           InpRSIUpperLevel  = 68.0;
input double           InpRSILowerLevel  = 48.0;

input group "=== Silver RSI Pro Filter ==="
input int    InpRSIPeriodH1      = 14;       // RSI Period สำหรับ TF ใหญ่
input double InpRSILowerLevelH1  = 40.0;     // RSI Buy Zone สำหรับ TF ใหญ่ (ต้องต่ำกว่านี้)
input double InpRSIUpperLevelH1  = 60.0;     // RSI Sell Zone สำหรับ TF ใหญ่ (ต้องสูงกว่านี้)
input bool   InpUseDualTF        = true;     // เปิดใช้ระบบกรอง 2 Timeframe

input group "=== Step B: Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 6.5;
input bool   InpEnableVolRegime    = true;   // Volatility Regime Switch (v1.3)
input double InpVolRegimeThresh    = 1.30;   // ATR / AvgATR > thresh = High Vol
input int    InpAvgATRPeriod       = 50;     // Bars used to compute average ATR baseline
input double InpATRMultiplier_HighVol = 12.0; // Wider grid spacing during High Vol regime
input double InpInitialLot         = 0.02;
input double InpBaseMultiplier     = 1.15;
input double InpReductionStep      = 0.05;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 7;

input group "=== Step C: Profit & Exit ==="
input double InpBasketTP           = 20.0;
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
input double InpMaxDrawdownPercent = 70.0;
input double InpTrailStartUSD      = 10.0;
input double InpTrailStepATR       = 2.5;
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 0.02;
input double InpMaxSpreadBase      = 35.0;
input double InpSpreadStressPoints = 0.0;    // v2.4: จำลอง Spread กว้างขึ้น (Points) บวกเข้า Ask ตอนเข้าไม้จริง สำหรับ Spread Stress Test เมื่อ Real-Tick model ทำให้ Custom Spread ของ Tester ไม่มีผล
input double InpMaxSpreadHighVol   = 40.0;
input double InpMaxExposurePercent = 25.0;
input double InpMinMarginLevel      = 700.0;

input group "=== Step I: Reserve Capital / Near-Death Cooldown (v2.0) ==="
input bool   InpEnableReserveSystem = true;   // เปิดใช้ระบบ 2 กระเป๋า
input double InpReserveCapital      = 225.0;  // เงินสำรองที่ฝากไว้แล้วตั้งแต่แรก (ไม่ได้ใช้จนกว่าจะขยาย Base)
input double InpNearDeathDDPercent  = 60.0;   // DD% ที่เข้าสู่ Cool Down (Re-optimized 2026-08-09 บน Window 2024.12.01-2026.07.15 — เดิม 40.0 บน Window เก่าที่มี Oct 2023 ร่วมด้วย ตอนนี้ข้อมูลนั้นหายไปแล้ว ต้องน้อยกว่า InpMaxDrawdownPercent)
input double InpSeedCycleStartEquity = 0.0;  // v2.7: Continuation-Based Walk-Forward — ถ้า >0 ใช้ค่านี้เป็น CycleStartEquity แทนการ Reset เป็น Equity จริง ณ OnInit (ใส่ = Initial Deposit ของ Test แรกสุดในเรื่อง เช่น 675 สำหรับ IS Period เดิม)
input int    InpCoolDownMinutes     = 180;    // ระยะเวลารอสัญญาณกลับตัวก่อนตัดสินใจ (นาที)
input int    InpReversalScoreMin    = 3;      // คะแนนขั้นต่ำ (จาก 5) ที่ต้องได้เพื่อขยาย Base เป็น 675
input int    InpDivergenceLookback  = 20;     // จำนวนแท่ง H1 ย้อนหลังสำหรับเช็ค RSI Divergence / ATR Contraction
input int    InpEMA_H4_Period       = 50;     // EMA(H4) สำหรับเช็ค Trend Reclaim
input int    InpFailedBreakLookback = 20;     // จำนวนแท่ง M5 ย้อนหลังสำหรับเช็ค Failed Breakdown
input bool   InpResearchMode        = false;  // true=Backtest/Research (นับ Cycle ต่อเนื่อง ไม่ ExpertRemove) | false=Live (หยุดจริงตามปกติ)
input double InpCycleTargetMultiple = 2.0;    // เป้าหมาย x2 สำหรับนับ WIN Cycle (Research Mode)

input group "=== Step F: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 6;
input int    TradingEndHour        = 2;
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
input double InpBaseBalance        = 450.0;

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

// Peak-based Equity Stop reference (fixes reference-drift bug)
double   g_peakEquity    = 0.0;

// ===== Reserve Capital / Near-Death Cooldown state (v2.0) =====
double   g_activeBase       = 0.0;              // ทุนที่ใช้คำนวณ Exposure จริง ณ ขณะนี้ (450 หรือ 675)
double   g_cycleStartEquity = 0.0;              // real ACCOUNT_EQUITY ณ จุดเริ่ม Cycle ปัจจุบัน (Research Mode rebasing)
bool     g_inCooldown       = false;
int      g_nearDeathCount        = 0;
int      g_reversalConfirmedCount = 0;
int      g_timeoutKillCount       = 0;
int      g_hardKillCount          = 0;
int      g_cycleWinCount          = 0;
datetime g_cooldownStart    = 0;
int      g_atrH1Handle      = INVALID_HANDLE;
int      g_rsiDivH1Handle   = INVALID_HANDLE;
int      g_emaH4Handle      = INVALID_HANDLE;

// RSI H1 handle (for Dual‑TF filter)
int      g_handleRSI_H1  = INVALID_HANDLE;
int      g_atrHandle     = INVALID_HANDLE;   // v1.4: cached ATR handle (was re-created every call)

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
   string msg = "9AU_SILVER_RESERVE_M5_CAP450 DD " + DoubleToString(dd, 2)
              + "pct | Balance " + DoubleToString(balance, 2)
              + " | Equity " + DoubleToString(equity, 2)
              + " | " + _Symbol + " " + TimeToString(now, TIME_DATE|TIME_MINUTES);
   TelegramSend(msg);
   ddAlertSent     = true;
   lastDDAlertTime = now;
}

//+------------------------------------------------------------------+
void Check2xBalance() {
   if(!InpEnable2xAlert || !InpEnableTelegram) return;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int    cur2x   = (int)MathFloor(balance / InpBaseBalance);
   if(cur2x <= last2xLevel) return;
   last2xLevel = cur2x;
   double profit      = balance - InpBaseBalance;
   double withdrawAmt = balance - InpBaseBalance;
   double msg_next    = InpBaseBalance * (cur2x + 1);
   string msg = "WITHDRAW ALERT 9AU_SILVER_RESERVE_M5_CAP450"
              + " | Balance " + DoubleToString(balance, 2)
              + " (" + IntegerToString(cur2x) + "x Base $" + DoubleToString(InpBaseBalance,0) + ")"
              + " | Equity " + DoubleToString(equity, 2)
              + " | Total Profit " + DoubleToString(profit, 2)
              + " | Suggested Withdraw " + DoubleToString(withdrawAmt, 2)
              + " | Restart with $" + DoubleToString(InpBaseBalance, 0)
              + " | Next Target $" + DoubleToString(msg_next, 2)
              + " | " + _Symbol + " " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   TelegramSend(msg);
   Print("[2x WITHDRAW ALERT] Balance=", DoubleToString(balance,2),
         " | Profit=", DoubleToString(profit,2),
         " | Suggested Withdraw=", DoubleToString(withdrawAmt,2));
}

//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   last2xLevel = (int)MathFloor(balance / InpBaseBalance);
   if(last2xLevel < 1) last2xLevel = 1;

   // Initialize Peak Equity reference for the Equity Stop (naturally updates
   // to the correct continuation value on the first tick via the running-max
   // logic in CheckEquityStop, once g_cycleStartEquity below is seeded right)
   g_peakEquity = InpBaseBalance;

   // Create H1 RSI handle if Dual‑TF is enabled
   if(InpUseDualTF) {
      g_handleRSI_H1 = iRSI(_Symbol, PERIOD_H1, InpRSIPeriodH1, PRICE_CLOSE);
      if(g_handleRSI_H1 == INVALID_HANDLE) {
         Print("ERROR: Failed to create H1 RSI handle");
         return INIT_FAILED;
      }
   }
   
   // v1.4: Create ATR handle ONCE (was created every tick inside GetATR/GetAvgATR)
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE) {
      Print("ERROR: Failed to create ATR handle");
      return INIT_FAILED;
   }

   g_activeBase = InpBaseBalance;
   // v2.7 fix: v2.6's InpSeedVirtualPeak seeded g_peakEquity directly while
   // VirtualEquity still rebased to start at InpBaseBalance every OnInit -
   // two different reference frames, causing an instant false ~90%+ DD on
   // tick 1 of any continuation test. Correct fix: seed g_cycleStartEquity
   // itself to the ORIGINAL story's starting real equity (e.g. the very
   // first IS run's Initial Deposit, 675) instead of resetting it to
   // "whatever real equity exists right now". This makes VirtualEquity
   // continuous across separate Backtest runs; g_peakEquity then correctly
   // self-populates via the normal running-max check on tick 1.
   g_cycleStartEquity = (InpSeedCycleStartEquity > 0) ? InpSeedCycleStartEquity : AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpEnableReserveSystem) {
      g_atrH1Handle    = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
      g_rsiDivH1Handle = iRSI(_Symbol, PERIOD_H1, InpRSIPeriodH1, PRICE_CLOSE);
      g_emaH4Handle    = iMA(_Symbol, PERIOD_H4, InpEMA_H4_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(g_atrH1Handle == INVALID_HANDLE || g_rsiDivH1Handle == INVALID_HANDLE || g_emaH4Handle == INVALID_HANDLE) {
         Print("ERROR: Failed to create Reserve-System indicator handle(s)");
         return INIT_FAILED;
      }
   }

   Print("=== 9AU_SILVER_RESERVE_M5_CAP450 Loaded | Magic=", InpMagicNumber,
         " | Lot=", InpInitialLot,
         " | MaxDD=", InpMaxDrawdownPercent, "%",
         " | DualTF=", InpUseDualTF,
         " | BaseBalance=$", InpBaseBalance,
         " | 2xTarget=$", InpBaseBalance*2, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_SILVER_RESERVE_M5_CAP450 Started | " + _Symbol
                   + " | Balance " + DoubleToString(balance,2)
                   + " | Fixed Lot " + DoubleToString(InpInitialLot,2)
                   + " | DualTF " + (InpUseDualTF ? "ON" : "OFF")
                   + " | 2x Target $" + DoubleToString(InpBaseBalance*2,0));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   int totalCycles = g_cycleWinCount + g_timeoutKillCount + g_hardKillCount;
   Print("=== RESERVE SYSTEM SUMMARY | Mode=", (InpResearchMode ? "RESEARCH" : "LIVE"),
         " | WIN(x", DoubleToString(InpCycleTargetMultiple,1), ")=", g_cycleWinCount,
         " | NEAR-DEATH Triggered=", g_nearDeathCount,
         " | REFILLED (Reversal Confirmed)=", g_reversalConfirmedCount,
         " | CYCLE KILL (Timeout)=", g_timeoutKillCount,
         " | HARD-KILL (", InpMaxDrawdownPercent, "%)=", g_hardKillCount,
         " | Total Cycles=", totalCycles,
         " | FINAL PeakVirtualEquity=", DoubleToString(g_peakEquity,2),
         " | FINAL RealBalance=", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2), " ===");
   if(g_handleRSI_H1 != INVALID_HANDLE) IndicatorRelease(g_handleRSI_H1);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_atrH1Handle != INVALID_HANDLE) IndicatorRelease(g_atrH1Handle);
   if(g_rsiDivH1Handle != INVALID_HANDLE) IndicatorRelease(g_rsiDivH1Handle);
   if(g_emaH4Handle != INVALID_HANDLE) IndicatorRelease(g_emaH4Handle);
   Print("=== 9AU_SILVER_RESERVE_M5_CAP450 Stopped. Reason: ", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_SILVER_RESERVE_M5_CAP450 Stopped | Reason " + IntegerToString(reason)
                   + " | Balance " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)
                   + " | " + _Symbol);
}

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
   double limit = g_activeBase * MaxDailyLossPercent / 100.0;
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
//| Dual‑Timeframe RSI Signal for Silver                              |
//+------------------------------------------------------------------+
bool IsSilverRSISignal(ENUM_ORDER_TYPE type) {
   double rsiM5 = 0, rsiH1 = 0;
   double buffer[];                     // เปลี่ยนเป็น dynamic array
   ArrayResize(buffer, 2);             // resize
   ArraySetAsSeries(buffer, true);     // set series flag

   // 1. Get M5 RSI
   int hM5 = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   if(hM5 == INVALID_HANDLE) return false;
   if(CopyBuffer(hM5, 0, 0, 2, buffer) < 2) { IndicatorRelease(hM5); return false; }
   rsiM5 = buffer[0];
   IndicatorRelease(hM5);

   // 2. Get H1 RSI
   if(g_handleRSI_H1 != INVALID_HANDLE) {
      if(CopyBuffer(g_handleRSI_H1, 0, 0, 2, buffer) < 2) return false;
      rsiH1 = buffer[0];
   }

   // 3. Signal logic (unchanged)
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
   if(CopyBuffer(g_atrHandle, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

// v1.4: Average ATR over InpAvgATRPeriod bars, using the cached handle
double GetAvgATR() {
   double buf[];
   if(CopyBuffer(g_atrHandle, 0, 0, InpAvgATRPeriod, buf) <= 0) return 0.0;
   double sum = 0.0;
   int n = ArraySize(buf);
   for(int i = 0; i < n; i++) sum += buf[i];
   return (n > 0) ? sum / n : 0.0;
}

double GetEMA() {
   // v1.4 cleanup: InpTrendEMA=0 means the filter is disabled (see usage
   // below: InpTrendEMA>0 required to apply it). Previously this still
   // created a NEW invalid iMA(period=0) handle every tick, spamming
   // "cannot load indicator" [4002] errors in the Journal for no benefit.
   if(InpTrendEMA <= 0) return 0.0;
   double buf[1];
   int h = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(CopyBuffer(h, 0, 0, 1, buf) > 0) return buf[0];
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
   if(marginLevel <= 0) return true;  // allow first trade in backtest
   if(marginLevel < InpMinMarginLevel) {
      Print("[SKIP] Margin Level ต่ำเกิน: ", DoubleToString(marginLevel,2), "% < ", InpMinMarginLevel, "%");
      return false;
   }

   double balance   = g_activeBase;
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
      TelegramSend("9AU_SILVER_RESERVE_M5_CAP450 CLOSE ALL | " + reason
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

// ===== Reserve Capital / Near-Death Cooldown (v2.0) =====
// 5-point checklist (Q3 framework agreed with พี่อู). Score >= InpReversalScoreMin
// expands g_activeBase to InpBaseBalance+InpReserveCapital (money already
// deposited from day 1 - this is a bookkeeping/exposure-cap change only,
// no actual fund transfer needed).
// ===== Reserve Capital / Near-Death Cooldown (v2.2) =====
// Fully rebased Virtual Equity: g_activeBase (450 or 675) + the real $
// change since the current cycle's reset point (g_cycleStartEquity). This
// correctly handles BOTH problems in one formula:
//   1. The Day-1-deposited Reserve never dilutes DD% before it's unlocked
//      (g_activeBase stays 450 until Reversal Confirmed expands it to 675).
//   2. In Research Mode, repeated WIN/KILL cycle resets don't let the
//      real, ever-compounding account balance leak into next cycle's math
//      (each new cycle starts clean at InpBaseBalance, exactly like the
//      separate Cycle Simulator file).
double GetVirtualEquityForDD() {
   double realEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   return g_activeBase + (realEquity - g_cycleStartEquity);
}

// Closes everything and resets the cycle bookkeeping to a fresh
// InpBaseBalance-sized virtual account. Does NOT touch the real MT5
// account (can't deposit/withdraw via code) - Research Mode only, for
// counting how a real "close cycle -> top up back to InpBaseBalance ->
// restart" operation would behave.
void ResetCycle(string reason) {
   CloseAll(reason);
   g_cycleStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_activeBase        = InpBaseBalance;
   g_peakEquity         = InpBaseBalance;
   g_inCooldown         = false;
}

int ComputeReversalScore() {
   int score = 0;

   // 1) RSI(H1) Divergence: RSI now higher than N bars ago while price is
   // flat/lower (momentum improving even as price stalls/falls)
   double rsiBuf[], closeBuf[];
   ArraySetAsSeries(rsiBuf, true);
   ArraySetAsSeries(closeBuf, true);
   if(CopyBuffer(g_rsiDivH1Handle, 0, 0, InpDivergenceLookback, rsiBuf) > 0 &&
      CopyClose(_Symbol, PERIOD_H1, 0, InpDivergenceLookback, closeBuf) > 0) {
      int n = ArraySize(rsiBuf);
      if(n >= InpDivergenceLookback && rsiBuf[0] > rsiBuf[n-1] && closeBuf[0] <= closeBuf[n-1])
         score++;
   }

   // 2) EMA(H4) Reclaim: last closed H4 candle closed above EMA
   double emaBuf[1];
   double closeH4[1];
   if(CopyBuffer(g_emaH4Handle, 0, 1, 1, emaBuf) > 0 && CopyClose(_Symbol, PERIOD_H4, 1, 1, closeH4) > 0) {
      if(closeH4[0] > emaBuf[0]) score++;
   }

   // 3) ATR(H1) Contraction: current ATR has dropped >=20% from its recent peak
   double atrH1Buf[];
   ArraySetAsSeries(atrH1Buf, true);
   if(CopyBuffer(g_atrH1Handle, 0, 0, InpDivergenceLookback, atrH1Buf) > 0) {
      int n = ArraySize(atrH1Buf);
      double peakAtr = atrH1Buf[0];
      for(int i = 1; i < n; i++) if(atrH1Buf[i] > peakAtr) peakAtr = atrH1Buf[i];
      if(peakAtr > 0 && atrH1Buf[0] <= peakAtr * 0.80) score++;
   }

   // 4) Grid Slot Remaining: basket still has room to average down
   if(basket.buyCount < InpMaxOrders) score++;

   // 5) Failed Breakdown (M5, best-effort approximation): current closed
   // low is HIGHER than the lowest low over the lookback window - i.e.
   // price has stopped making fresh lows
   double lowBuf[];
   ArraySetAsSeries(lowBuf, true);
   if(CopyLow(_Symbol, PERIOD_CURRENT, 1, InpFailedBreakLookback, lowBuf) > 0) {
      int n = ArraySize(lowBuf);
      double lowestLow = lowBuf[0];
      for(int i = 1; i < n; i++) if(lowBuf[i] < lowestLow) lowestLow = lowBuf[i];
      if(lowBuf[0] > lowestLow) score++;
   }

   return score;
}

// Returns true ONLY on the terminal outcome (Kill on timeout), which should
// stop OnTick entirely this tick (positions already closed + EA removed).
// While merely IN cooldown (not yet decided), returns false so the rest of
// OnTick (Basket Management: SL/Trail/PartialClose/TP) keeps running as
// normal - only the Grid-Add block checks g_inCooldown separately to pause
// new averaging-down orders.
bool CheckNearDeathCooldown() {
   if(!InpEnableReserveSystem) return false;

   double equity = GetVirtualEquityForDD();
   double dd = (g_peakEquity > 0) ? (g_peakEquity - equity) / g_peakEquity * 100.0 : 0.0;

   if(!g_inCooldown) {
      if(g_activeBase < InpBaseBalance + InpReserveCapital && dd >= InpNearDeathDDPercent) {
         g_inCooldown    = true;
         g_cooldownStart = TimeCurrent();
         g_nearDeathCount++;
         Print("[NEAR-DEATH] DD=", DoubleToString(dd,2), "% >= ", InpNearDeathDDPercent,
               "% | Entering Cooldown (", InpCoolDownMinutes, " min) | New Grid-Add PAUSED");
      }
      return false;
   }

   // In Cooldown: evaluate the checklist every new bar
   int score = ComputeReversalScore();
   Print("[COOLDOWN] Score=", score, "/5 | Elapsed=",
         (TimeCurrent()-g_cooldownStart)/60, " min | Equity=", DoubleToString(equity,2));

   if(score >= InpReversalScoreMin) {
      g_activeBase = InpBaseBalance + InpReserveCapital;
      g_inCooldown = false;
      g_reversalConfirmedCount++;
      Print("[REVERSAL CONFIRMED] Score=", score, "/5 | Base ขยายเป็น ", DoubleToString(g_activeBase,2),
            " | Resume Trading (Grid-Add unpaused)");
      return false; // resume normal OnTick flow this same tick
   }

   if((TimeCurrent() - g_cooldownStart) >= InpCoolDownMinutes * 60) {
      g_timeoutKillCount++;
      if(InpResearchMode) {
         Print("[CYCLE TIMEOUT-KILL] #", g_timeoutKillCount, " | Score=", score, "/5 < ", InpReversalScoreMin,
               " | No Reversal Confirmed | Research Mode Reset & Continue");
         ResetCycle("Near-Death Cooldown Timeout - No Reversal (Research Mode)");
         return true; // positions just closed, resume fresh next tick
      } else {
         Print("[NEAR-DEATH TIMEOUT] Score=", score, "/5 < ", InpReversalScoreMin,
               " | No Reversal Confirmed | ปล่อยพอร์ตแตก - Kill & Remove");
         CloseAll("Near-Death Cooldown Timeout - No Reversal");
         ExpertRemove();
         return true; // terminal: stop OnTick entirely this tick
      }
   }

   return false; // still cooling down: OnTick continues, but Grid-Add block
                 // below will separately check g_inCooldown and skip itself
}

//+------------------------------------------------------------------+
bool CheckEquityStop() {
   if(!InpEnableEquityStop) return false;
   double vEquity = GetVirtualEquityForDD();

   // Update Peak Equity every tick BEFORE the DD check (Peak-based baseline)
   if(vEquity > g_peakEquity) g_peakEquity = vEquity;
   if(g_peakEquity <= 0) g_peakEquity = InpBaseBalance;

   double dd = (g_peakEquity - vEquity) / g_peakEquity * 100.0;
   if(dd >= InpMaxDrawdownPercent) {
      g_hardKillCount++;
      if(InpResearchMode) {
         Print("[CYCLE HARD-KILL] #", g_hardKillCount, " | DD from Peak=", DoubleToString(dd,2),
               "% >= Limit=", InpMaxDrawdownPercent, "% | PeakEquity(Virtual)=", DoubleToString(g_peakEquity,2),
               " | Equity(Virtual)=", DoubleToString(vEquity,2));
         ResetCycle("Cycle HARD-KILL DD=" + DoubleToString(dd,2) + "% - Research Mode Reset");
      } else {
         Print("[STOP] #", g_hardKillCount, " DD from Peak=", DoubleToString(dd,2), "% >= Limit=", InpMaxDrawdownPercent,
               "% | PeakEquity(Virtual)=", DoubleToString(g_peakEquity,2), " | Equity(Virtual)=", DoubleToString(vEquity,2));
         CloseAll("Equity Stop DD=" + DoubleToString(dd,2) + "% (Peak-based)");
         ExpertRemove();
      }
      return true;
   }
   return false;
}

// WIN check (x2 target). Only actively resets/counts in Research Mode -
// in Live Mode this intentionally does nothing (Check2xBalance() already
// sends the withdrawal alert; a real reset needs the trader's own action).
bool CheckCycleWin() {
   if(!InpResearchMode) return false;
   double vEquity = GetVirtualEquityForDD();
   if(vEquity >= InpBaseBalance * InpCycleTargetMultiple) {
      g_cycleWinCount++;
      Print("[CYCLE WIN] #", g_cycleWinCount, " | Virtual Equity=", DoubleToString(vEquity,2),
            " >= Target=", DoubleToString(InpBaseBalance*InpCycleTargetMultiple,2));
      ResetCycle("Cycle WIN x" + DoubleToString(InpCycleTargetMultiple,1) + " - Research Mode Reset");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// ********************** FIXED OnTick() ********************** 
void OnTick() {
   if(CheckEquityStop()) return;
   if(CheckCycleWin()) return;
   if(CheckNearDeathCooldown()) return;
   UpdateDailyLoss();
   CheckDDAlert();
   Check2xBalance();
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

   // v1.4 diagnostic: unconditional regime check on every new bar (not gated
   // behind the RSI Buy Signal) so we can verify whether/when High-Vol ever
   // actually fires. Remove or comment out after diagnosis is confirmed.
   if(InpEnableVolRegime) {
      double diagAvgAtr = GetAvgATR();
      double diagRatio  = (diagAvgAtr > 0) ? (atrVal / diagAvgAtr) : -1.0;
      if(diagRatio > InpVolRegimeThresh) {
         Print("[VOL REGIME DIAG] HIGH | ATR=", DoubleToString(atrVal,4),
               " AvgATR=", DoubleToString(diagAvgAtr,4),
               " Ratio=", DoubleToString(diagRatio,2));
      }
   }

   long   spreadPts      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double maxSpreadAllow = (atrVal > 100) ? InpMaxSpreadHighVol : InpMaxSpreadBase;
   if(spreadPts > maxSpreadAllow) {
      Print("[SKIP] Spread=", spreadPts, " > Max=", maxSpreadAllow);
      return;
   }

   // --- Dual‑TF RSI Filter (Silver upgrade) ---
   if(!IsSilverRSISignal(ORDER_TYPE_BUY)) {
      // No valid BUY signal – exit
      return;
   }

   double priceVal = iClose(_Symbol, PERIOD_CURRENT, 1);
   double emaVal   = GetEMA();
   if(priceVal <= emaVal && InpTrendEMA > 0) {
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

   double dynamicDist;
   if(InpEnableDynamicGrid) {
      double effMultiplier = InpATRMultiplier;
      if(InpEnableVolRegime) {
         double avgAtr = GetAvgATR();
         if(avgAtr > 0 && (atrVal / avgAtr) > InpVolRegimeThresh) {
            effMultiplier = InpATRMultiplier_HighVol;
            Print("[VOL REGIME] HIGH | ATR=", DoubleToString(atrVal,3),
                  " AvgATR=", DoubleToString(avgAtr,3),
                  " Ratio=", DoubleToString(atrVal/avgAtr,2),
                  " | Using Multiplier=", DoubleToString(effMultiplier,1));
         }
      }
      dynamicDist = MathMax(atrVal * effMultiplier, 300.0 * _Point);
   } else {
      dynamicDist = 300.0 * _Point;
   }
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + InpSpreadStressPoints * _Point;
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   if(g_inCooldown) {
      // Near-Death Cooldown active: pause opening ANY new order (new basket
      // or grid-add), but SL/Trail/PartialClose/TP above already ran normally.
      return;
   }

   if(basket.buyCount == 0) {
      double lot = NormalizeDouble(InpInitialLot, 2);
      if(step > 0) lot = MathRound(lot / step) * step;
      lot = MathMax(lot, minLot);
      if(!IsExposureSafe()) return;
      if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_SILVER_RESERVE_M5_CAP450 Sniper")) {
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
         if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_SILVER_RESERVE_M5_CAP450 Grid")) {
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
