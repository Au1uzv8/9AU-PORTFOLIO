//+------------------------------------------------------------------+
//|     9AU_USDJPY_SNIPER_M5_CAP300_V1_0.mq5                              |
//|     James Consultant | RSI Rebound + EMA Pullback + ADX          |
//|     Long-Only Basket Grid with Cut Loss / Depth Limiter          |
//+------------------------------------------------------------------+
#property copyright "9Au & James Consultant - R300"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input int      InpMagicNumber      = 515253;

input group "=== Step A: Filter ==="
input int              InpTrendEMA       = 200;      // Trend EMA period on H1
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_H1;
input int              InpRSIPeriod      = 14;
input double           InpRSIUpperLevel  = 58.0;     // Not used for buy (kept for legacy)
input double           InpRSILowerLevel  = 30.0;     // Not used directly now (kept for legacy)
input double           InpRSIBuyZoneHigh = 45.0;     // 45.0 Buy only if M5 RSI < this level (prevent overbought)

input group "=== Silver RSI Pro Filter ==="
input int    InpRSIPeriodH1      = 14;
input double InpRSILowerLevelH1  = 50.0;             // Not used now
input double InpRSIUpperLevelH1  = 60.0;             // Max H1 RSI allowed to enter buy (avoid overbought in higher TF)
input bool   InpUseDualTF        = true;

input group "=== Trend Strength (ADX) ==="
input int    InpADXPeriod        = 14;
input double InpADXMin           = 20.0;             // 20.0 Minimum ADX to ensure trend strength

input group "=== Step B: Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 3.5;            // Grid distance in ATR (slightly wider)
input double InpInitialLot         = 0.01;
input double InpBaseMultiplier     = 1.12;
input double InpReductionStep      = 0.03;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 4;

input group "=== Step C: Profit & Exit ==="
input double InpBasketTP           = 25.0;           // Take profit for whole basket
input double InpBasketCutLoss      = 45.0;           // Cut loss for basket
input double InpMaxGridDepthATR    = 6.0;            // Max allowed grid depth in ATR
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
input double InpMaxDrawdownPercent = 18.0;
input double InpTrailStartUSD      = 18.0;
input double InpTrailStepATR       = 1.8;
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 0.02;
input double InpMaxSpreadBase      = 210.0;
input double InpMaxSpreadHighVol   = 290.0;
input double InpMaxExposurePercent = 18.0;
input double InpMinMarginLevel      = 700.0;

input group "=== Step F: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 8;
input int    TradingEndHour        = 23;
input bool   StopFridayAfterClose  = true;
input int    FridayCloseHour       = 18;

input group "=== Step G: Daily Loss Limit ==="
input bool   EnableDailyLossLimit  = true;
input double MaxDailyLossPercent   = 3.0;

input group "=== Step H: Telegram Notify ==="
input bool   InpEnableTelegram     = true;
input string InpToken              = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID             = "8053031320";
input double InpTelegramDDAlert    = 15.0;
input bool   InpEnable2xAlert      = true;
input double InpBaseBalance        = 300.0;

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
double   dailyLoss       = 0.0;
bool     partialDone     = false;
datetime lastGridTime    = 0;      // cooldown between grid legs

int      handleRSI_M5, handleRSI_H1, handleADX, handleTrendMA;
MqlCalendarValue todayEvents[];
datetime lastNewsUpdate = 0;

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
   int h = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   if(CopyBuffer(h, 0, 0, 1, buf) > 0) return buf[0];
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
         // lowestBuyPrice = lowest open price = deepest grid leg (grid distance reference)
         if(basket.lowestBuyPrice == 0.0 || price < basket.lowestBuyPrice) {
            basket.lowestBuyPrice = price;
            basket.lastBuyLot     = lot;
         }
         // lastBuyPrice = track any buy (kept for legacy reference)
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

double GetFirstBuyPrice() {
   return basket.oldestBuyPrice;
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

bool IsExposureSafe() {
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel > 0 && marginLevel < InpMinMarginLevel) {
      Print("[SKIP] Margin Level ต่ำเกิน: ", DoubleToString(marginLevel,2), "% < ", InpMinMarginLevel, "%");
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
      if(cntry.currency != "USD") continue;
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
   MqlDateTime dt; TimeLocal(dt);
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
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return false;
   double dd = (balance - equity) / balance * 100.0;
   if(dd >= InpMaxDrawdownPercent) {
      CloseAll("Equity Stop DD=" + DoubleToString(dd,2) + "%");
      ExpertRemove();
      return true;
   }
   return false;
}

void UpdateDailyLoss() {
   datetime today = TimeCurrent() / 86400 * 86400;
   if(today != currentDay) {
      currentDay  = today;
      dailyLoss   = 0.0;
      partialDone = false;
   }
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double loss = bal - eq;
   if(loss > dailyLoss) dailyLoss = loss;
}

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

   handleRSI_M5  = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   handleRSI_H1  = iRSI(_Symbol, PERIOD_H1, InpRSIPeriodH1, PRICE_CLOSE);
   handleADX     = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   handleTrendMA = iMA(_Symbol, InpFilterTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(handleRSI_M5 == INVALID_HANDLE || handleRSI_H1 == INVALID_HANDLE ||
      handleADX == INVALID_HANDLE || handleTrendMA == INVALID_HANDLE)
   {
      Print("Indicator creation failed");
      return INIT_FAILED;
   }

   Print("9AU SNIPER Loaded | RSI Rebound + EMA Pullback + ADX | Magic=", InpMagicNumber,
         " | EMA=", InpTrendEMA, " | ADX>=", InpADXMin,
         " | CutLoss=", InpBasketCutLoss, " TP=", InpBasketTP);
   if(InpEnableTelegram)
      TelegramSend("9AU SNIPER Started | " + _Symbol + " | Balance " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   IndicatorRelease(handleRSI_M5);
   IndicatorRelease(handleRSI_H1);
   IndicatorRelease(handleADX);
   IndicatorRelease(handleTrendMA);
}

//+------------------------------------------------------------------+
//| Main OnTick                                                      |
//+------------------------------------------------------------------+
void OnTick() {
   if(CheckEquityStop()) return;
   UpdateDailyLoss();
   if(IsDailyLossExceeded()) return;

   UpdateBasketInfo();

   // --- Basket Cut Loss: every tick ---
   if(basket.buyCount > 0 && basket.totalProfit <= -InpBasketCutLoss) {
      CloseAll("Basket Cut Loss $" + DoubleToString(InpBasketCutLoss,2));
      partialDone = false;
      return;
   }

   // --- Grid Depth Limiter: every tick ---
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(basket.buyCount > 0 && GetFirstBuyPrice() > 0) {
      double atrCheck = GetATR();
      if(atrCheck > 0 && (GetFirstBuyPrice() - bid) / atrCheck >= InpMaxGridDepthATR) {
         CloseAll("Grid Depth Exceeded " + DoubleToString((GetFirstBuyPrice()-bid)/atrCheck,1) + "x ATR");
         partialDone = false;
         return;
      }
   }

   // --- Grid Leg: every tick, price-distance only ---
   // IsExposureSafe() excluded — nominal JPY exposure always exceeds % limit on small accounts
   // Safety: InpMaxOrders + InpMaxGridDepthATR + InpBasketCutLoss
   double atrVal = GetATR();
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
         UpdateBasketInfo(); // refresh lastBuyPrice immediately so next leg uses correct reference
         Print("[OPEN] Grid Buy #", basket.buyCount, " Lot=", DoubleToString(lot,2),
               " Dist=", DoubleToString(basket.lastBuyPrice - ask, 3));
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
   double maxSpreadAllow = (atrVal > 100) ? InpMaxSpreadHighVol : InpMaxSpreadBase;
   if(spreadPts > maxSpreadAllow) {
      Print("[SKIP] Spread=", spreadPts, " > Max=", maxSpreadAllow);
      return;
   }

   // --- First Entry: full signal filter required ---
   if(IsBuySignal() && basket.sellCount == 0 && basket.buyCount == 0) {
      double lot = NormalizeDouble(InpInitialLot, 2);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      lot = MathRound(lot / step) * step;
      lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
      if(IsExposureSafe() && trade.Buy(lot, _Symbol, ask, 0, 0, "Sniper")) {
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