โครงสร้าง Session Summary ที่ดีต้องตอบ 3 คำถามให้ Claude ครั้งต่อไปได้ทันที: **"งานคืออะไร / ถึงไหนแล้ว / ต่อจากตรงไหน"** — โดยไม่ต้องอ่านย้อน conversation เลย
---
FRONTMATTER — machine-readable
---
session_id: YYYY-MM-DD_EA-NAME_v1.0
status: IN_PROGRESS | DONE | BLOCKED
next_action: <กริยา + เป้าหมาย 1 บรรทัด>
---
SECTION 1 — CONTEXT (2–3 บรรทัด)
## Context
- EA: <ชื่อ> | Symbol: <xxx> | TF: <M5/H1>
- Objective: <automation / alert-based / backtest only>
- Magic#: <xxxx> | Port: <01/02/03>
SECTION 2 — DECISIONS MADE (bullet สั้น)
## Decisions
- [CONFIRMED] <สิ่งที่ตัดสินใจแล้ว — ห้ามเปลี่ยน>
- [CONFIRMED] <parameter / logic / threshold ที่ lock แล้ว>
- [REJECTED] <แนวทางที่ทดสอบแล้วไม่ผ่าน + เหตุผล>
SECTION 3 — CURRENT STATE (snapshot)
## State
- Last version: v<x.x> — <สิ่งที่เปลี่ยนใน version นี้>
- Backtest result: PF=<x.xx> | WR=<xx%> | DD=<xx%> | Sharpe=<x.xx>
- Known issues: <bug / limitation ที่ยังเปิดอยู่>
SECTION 4 — LESSONS LEARNED (สิ่งที่เจ็บปวดมา)
## Lessons
- <ข้อผิดพลาดที่เจอ + วิธีแก้ที่ใช้ได้จริง>
- <กฎที่ค้นพบ — ระบุชัดว่า "ห้าม..." หรือ "ต้อง...">
SECTION 5 — NEXT STEPS (resume point)
## Next Steps
- [ ] <งานที่ต้องทำต่อ — เรียงลำดับ priority>
- [ ] <เงื่อนไขก่อนเข้า Forward Test / Live>
# END OF SESSION
---
**กฎที่ทำให้ summary มีประสิทธิภาพจริง:**

`next_action` ใน frontmatter คือสิ่งสำคัญที่สุด — Claude อ่านบรรทัดนี้บรรทัดเดียวก็รู้ว่าต้องทำอะไรต่อ โดยไม่ต้องอ่านทั้งไฟล์

`[CONFIRMED]` vs `[REJECTED]` ป้องกันการ debate ซ้ำ — Claude จะไม่เสนอแนวทางที่ถูก reject ไปแล้ว

`State` section ใช้ตัวเลขล้วน — ไม่มี prose ไม่มีการตีความ Claude อ่านตัวเลขเทียบ threshold ได้ทันที

`Lessons` section เป็นส่วนที่มีคุณค่ามากที่สุดในระยะยาว เพราะ session ใหม่จะไม่ทำผิดซ้ำ

**ขนาดที่เหมาะสม:** ไม่เกิน 40 บรรทัด — ถ้ายาวกว่านี้แสดงว่าใส่ข้อมูลที่ควรอยู่ใน Obsidian ไม่ใช่ใน summary