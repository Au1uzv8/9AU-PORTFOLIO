# Context Summary: AI Agent Automation & MetaTrader MCP Integration

> ไฟล์นี้สรุปบริบทจาก Session ก่อนหน้า สำหรับวางเปิด Session ใหม่ให้เจมส์ (Claude) เข้าใจสถานะทั้งหมดทันทีโดยไม่ต้องอธิบายซ้ำ

---

## 1. Concept (เป้าหมาย)

พี่อูต้องการให้เจมส์ทำหน้าที่ "สมองหลัก" ออกแบบและบริหารแนวคิดการเทรด โดยส่งต่อคำสั่งผ่าน AI Agent (รันด้วย Google Gemini API Key ของพี่อูเอง โมเดล `gemini-3.5-flash`) ให้ Agent นั้นเชื่อมต่อกับ **MetaTrader MCP Server** (ariadng/metatrader-mcp-server) เพื่อควบคุม MetaTrader 5

โครงสร้างที่ตั้งใจไว้คือรูปแบบเดียวกับ Workflow เดิมที่ใช้พัฒนา EA: เจมส์ออกแบบ+วางแผน → Agent (Hermes/OpenClaw) รับคำสั่งไปดำเนินการ → Loop กลับมาให้เจมส์ตรวจสอบ

**จุดที่ยังไม่ได้ข้อสรุป (ต้องตัดสินใจใน Session ใหม่ก่อนเริ่มจริง)**: รอบก่อนหน้า เจมส์ประเมินไว้ว่าการให้ AI Agent เชื่อมต่อ MetaTrader MCP Server แบบ **Direct Execution** (สั่ง Buy/Sell/Close ทันทีโดยไม่ต้องขออนุมัติ ตามที่ Skill ของ MCP Server นี้ออกแบบมาโดย Default) มีความเสี่ยงสูง เพราะขัดกับหลักการ Manual Approval ที่พี่อูยึดถือมาตลอด และข้ามระบบป้องกันความเสี่ยงที่ฝังอยู่ใน EA (Reserve/Near-Death Cooldown, Virtual Balance) ไปเลย ข้อเสนอเดิมคือ **เปิดใช้เฉพาะ Tool กลุ่ม Read-Only** (get_account_info, get_symbol_price, get_all_positions) ให้ Agent ใช้แค่ดึงข้อมูลมาวิเคราะห์/ทำ Dashboard เท่านั้น ส่วน Order Execution จริงยังคงให้ EA ที่ผ่าน Validation Protocol เป็นผู้ดำเนินการ **ไม่ใช่ให้ LLM สั่ง Order ตรงผ่านภาษาธรรมชาติ**

---

## 2. Environment (สภาพแวดล้อมปัจจุบัน)

| ระบบ | สถานะ | หมายเหตุ |
|---|---|---|
| **Hermes Agent** | Hold ไว้ (ยังไม่ Uninstall) | รันบน VPS (Hostinger) เชื่อม Google Gemini API Key |
| **OpenClaw** | Active ใช้งานอยู่ | รันทั้งแบบ Terminal แยก และเป็น VS Code Extension บนเครื่อง Local (บ้าน) ใช้ Google API Key เดียวกับ Hermes |
| **Continue.dev** | ติดตั้งไว้เป็น Backup | VS Code Extension ใช้ Google API Key เดียวกับ OpenClaw |
| **VS Code GitHub Copilot** | Pause ชั่วคราว | โควต้า Free Plan ใช้ไป 89% Reset ทุกวันที่ 1 ของเดือนถัดไป (เหลือเวลารออีกราว 17 วันนับจากที่หยุดใช้) |
| **Google Cloud Project (Gemini API)** | Free Tier | Key เดียวใช้ร่วมกันได้หลาย Platform (ยืนยันจาก Google Gemini App) แต่ Quota Bucket แชร์ร่วมกันตาม Model ไม่ใช่ตาม Platform |

**Portfolio ที่เกี่ยวข้อง**: EA Portfolio 11 ตัว แบ่งเป็น 3 Combined Port — Port-01 (Gold+USDJPY), Port-02 (BTC+AUDCAD), Port-03 (Silver+GBPJPY) เอกสารหลักอยู่ใน Obsidian Vault + GitHub Pages Dashboard

---

## 3. Behavior / บทเรียนสำคัญจากการใช้งาน Gemini Free Tier

จาก Canary Test ที่ทำกับ Hermes (แก้ไข Silver EA เพิ่ม RSI Filter) พบพฤติกรรมสำคัญที่ต้องระวังซ้ำ:

1. **Gemini Pro ทุกรุ่น (3.1-pro-preview, 3-pro-preview, 2.5-pro) ไม่มี Free Tier แล้ว** ตั้งแต่เมษายน 2026 ต้องเปิด Billing เท่านั้น
2. **gemini-2.5-flash กำลังถูกปิดก่อนกำหนดจริง** (กำหนดทางการ 16 ต.ค. 2026 แต่เริ่มขึ้น 404 ตั้งแต่ 9 ก.ค. 2026) หลีกเลี่ยงตัวนี้
3. **โมเดลที่มีคำว่า `-exp` หรือรุ่นเก่ากว่า 3.x** (เช่น gemini-2.0-flash-thinking-exp, gemini-1.5-pro) เสี่ยงถูกปลดระวางกลางทาง
4. **Reasoning/Thinking Effort ควรตั้งเป็น Medium** ไม่ใช่ High เพราะ High ทำให้ 1 คำสั่งยิง Internal API Call ถี่เกิน จนชน Rate Limit ง่าย
5. **Quota นับแยกตาม Model ไม่ใช่ตาม Effort หรือ Platform** — ถ้าโดน 429 การลด Effort ไม่ช่วย ต้องสลับ Model หรือรอ Cooldown
6. **Agent มีกลไก Auto-Retry + Auto-Fallback ในตัว** ที่อาจสลับ Model เองเมื่อชน Rate Limit โดยไม่แจ้งล่วงหน้า แม้ตั้ง Approval=Manual ไว้ก็ตาม เป็นความเสี่ยงที่ยังไม่มีทางแก้ 100%
7. **Context ที่สะสมยาวในหนึ่ง Session ยิ่งเสี่ยงชน Token-based Rate Limit** แนะนำเปิด Session ใหม่บ่อยๆ เมื่อเริ่มงานใหม่
8. **Model แนะนำสำหรับงาน Coding/Agentic**: `gemini-3.5-flash` เป็นหลัก (Free Tier, Benchmark ดีสุดในกลุ่มฟรี) และ `gemini-3.1-flash-lite` เป็น Fallback

---

## 4. Usage / Config ปัจจุบันที่ตั้งไว้แล้ว

- OpenClaw: `agents.defaults.model.primary` = `google/gemini-3.5-flash` (ตั้งค่าถาวรผ่าน `openclaw config set` แล้ว Restart Gateway เรียบร้อย)
- OpenClaw: ปิดช่องโหว่ `gateway.controlUi.allowInsecureAuth` แล้ว (เคยเปิดอยู่ เป็นความเสี่ยงด้าน Security ระดับ CVSS 8.3 ที่ถูกแก้ไปแล้ว)
- Approval Mode: Manual (ตั้งใจไว้สำหรับทั้ง Hermes และ OpenClaw)
- File Checkpoints (Rollback Snapshot ก่อนแก้ไฟล์): เปิดใช้งานอยู่

---

## 5. สถานะล่าสุดของงานที่ค้างอยู่ (ยังไม่ปิดจบ)

**Canary Test บน Silver EA (9AU_SILVER_RESERVE_M5_CAP450.mq5)**: สั่งให้ Hermes เพิ่ม RSI Confirmation Filter บนไฟล์สำเนา (`_CANARY_TEST.mq5`) เพื่อทดสอบคุณภาพ Code ก่อนใช้งานจริง งานเขียนไปถึงขั้นตอนสร้าง RSI Handle + CopyBuffer + เงื่อนไข Overbought/Oversold บางส่วนแล้ว **แต่ยังไม่ได้ยืนยันว่าเสร็จสมบูรณ์ 100%** และไม่แน่ใจว่า Code ทุกส่วนเขียนโดย Model เดียวกันตลอด (เพราะระหว่างทางมีการ Auto-Fallback สลับ Model เกิดขึ้น) **ควรตรวจสอบ Diff ทั้งไฟล์ซ้ำอีกรอบก่อนเชื่อถือผลการทดสอบนี้**

**MetaTrader MCP Server**: ยังอยู่ขั้นตอนประเมิน ยังไม่ได้ติดตั้งจริง รอการตัดสินใจเรื่องขอบเขตสิทธิ์ (Read-only vs Full Execution) ตามที่สรุปไว้ในข้อ 1

---

## สิ่งที่ต้องทำต่อใน Session ใหม่

1. ตัดสินใจขอบเขตสิทธิ์ของ MetaTrader MCP Server ก่อนติดตั้ง (Read-only แนะนำ / Full Execution มีความเสี่ยงสูง)
2. ถ้าตัดสินใจแล้ว ออกแบบ Prompt/Config การเชื่อมต่อ MCP Server กับ Agent ที่เลือกใช้ (OpenClaw หรือ Hermes)
3. ปิดงาน Canary Test ของ Silver EA ให้ครบก่อน ถ้ายังไม่เสร็จ
