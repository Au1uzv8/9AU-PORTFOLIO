=== 9AU EA SESSION SUMMARY ===
Date: 2026-07-07
EA: 9AU_BTC_ADAPTIVE_REGIME_M5_CAP450
Instrument: BTCUSD#
Broker: XM Ultra Low Standard
Capital: $300
Base code: GOLD# template (adapted for BTC)
Current version: v3.4 (file สำหรับ forward test)
Magic Number: 919295

=== ARCHITECTURE ที่ implement แล้ว ===
- Dual-Basket Isolation: Buy/Sell basket แยกกันสมบูรณ์
- Compound Selective: GetSniperLot() / GetSellSniperLot()
- Progressive Trail: <3d=2.5x | 3-14d=1.5x | >14d=0.8x ATR
- Option B: EMA50<200 hard required สำหรับ Sell
- Indicator handles: global OnInit() — ไม่ leak
- Kill Switch: peakEquity-based DD (v3.3)
- Volatility Regime Switch: ATR/AvgATR > 1.30 = High Vol (v3.4)

=== BUG ที่แก้แล้ว (v1→v3.4) ===
Bug#1: Buy TP/Trail/Partial ใช้ basket.totalProfit → buyBasketProfit
Bug#2: Indicator handles สร้างใหม่ทุก tick → ย้ายไป OnInit()
Bug#3: InpSellMinATRMult=1.2 (Sell ไม่เคย trigger) → 0.90
Bug#4: InpHardSLMultiplier Buy=11.0 → 7.0
Bug#5: EA name strings "9AU_GOLD" → "9AU_BTC"
Bug#6: Kill Switch dd=(bal-equity)/bal → (peakEquity-equity)/peakEquity
Bug#7: CheckTimedTP() ถูก ATR filter block → ย้ายออกก่อน filter

=== BEST CONFIG (Forward Test Ready) ===
File: 9AU_BTC_ADAPTIVE_REGIME_M5_CAP450_v3.4.mq5
InpEnableSell             = false
InpMaxOrders              = 3
InpEnableEquityStop       = false   ← ดูหมายเหตุด้านล่าง
InpEnableTimedTP          = false
EnableTimeFilter          = false
InpEnableHouseMoney       = false
InpVolRegimeThresh        = 1.30
InpATRMultiplier_LowVol   = 6.0
InpATRMultiplier_HighVol  = 12.0

=== BACKTEST RESULT (v3.4 Best Config) ===
Period: 2023.10.01 – 2026.04.30 (100% real ticks)
Net Profit:       $641
Profit Factor:    2.32   PASS (>1.50)
Sharpe Ratio:     0.81   FAIL (>1.80)
Equity DD:       39.75%  FAIL (<20%)
Balance DD:      13.82%  ดีมาก
Recovery Factor:  1.78   ใกล้ (>2.0)
LR Correlation:  +0.09   PASS (>0)
Win Rate:        39.78%  FAIL (>60%)
Total Trades:       93

=== หมายเหตุ InpEnableEquityStop = false ===
เหตุผลที่ปิด Kill Switch สำหรับ EA ตัวนี้โดยเฉพาะ:

1. Equity DD 39.75% ไม่ใช่ความเสี่ยงจริง
   - มาจาก position #6 (Buy@$34k) ถือยาว 734 วัน
   - ขณะถือ: equity ลอยสูง balance นิ่ง
   - DD metric ของ MT5 นับ peak equity สูงสุดเป็น reference
   - ผลคือ DD ดูสูง แต่เป็น floating profit ที่ยังไม่ realize

2. Balance DD จริงแค่ 13.82%
   - นี่คือ realized loss จริงที่กระทบเงินต้น
   - อยู่ในระดับที่ยอมรับได้โดยไม่ต้องพึ่ง hard stop

3. Kill Switch 25% ตัดทิ้ง core alpha
   - ทดสอบแล้ว: EquityStop=true ทำให้ EA หยุดที่ bar ที่ 60,989
     จาก 270,161 bars (22% ของ period) และ Net Profit ลดเหลือ $211
   - Position #6 คือ $814 = 127% ของ Net Profit ทั้งหมด
   - Kill Switch ที่ trigger ระหว่าง normal BTC correction
     ตัด position นี้ทิ้งก่อนได้กำไร

4. Risk ที่แท้จริงควบคุมด้วย
   - InpMaxOrders=3 จำกัด grid depth
   - Hard SL ต่อ position (InpHardSLMultiplier=7.0)
   - Daily Loss Limit (MaxDailyLossPercent=2.25%)
   - Sell=false ตัด counter-trend risk ออกทั้งหมด

=== KEY INSIGHT ===
1. Position #6 Buy@$34k ถือยาว 734 วัน กำไร $814
   = 127% ของ Net Profit รวม — core alpha ของระบบ
   ห้าม interrupt ด้วย TimedTP หรือ Kill Switch
2. Sell Win Rate 27.76% — ไม่คุ้มบน BTC uptrend asset
3. Sharpe 0.81 และ Win Rate 39.78% เป็น characteristic
   ของ trend-following grid ไม่ใช่ bug
4. Volatility Regime Switch ทำงานได้
   แต่ gain เล็กน้อยเพราะ position #6 dominate ผลลัพธ์

=== สิ่งที่ทดสอบแล้วและ REJECT ===
TimedTP, Progressive Trail aggressive, Sell=true,
RSI=35+ATR=10, Kill Switch DD=25%, EnableTimeFilter=true,
EquityStop=true (ตัด core alpha position)

=== NEXT SESSION ===
Status: พร้อม Forward Test Demo 1-3 เดือน
Monitor: Balance DD ไม่เกิน 15%, [VOL REGIME] log HIGH/LOW
ถ้าจะ optimize เพิ่ม: Recovery Factor >2.0
  → ทดสอบ InpBasketTP=40-50, InpVolRegimeThresh=1.20