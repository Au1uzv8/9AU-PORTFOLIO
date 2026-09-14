---
checkpoint_id: "CKP-{MSN_id}-{SEQ}"
mission_id: "MSN-{id}"
session_date: "YYYY-MM-DD"
status: "open | complete | blocked"
---

# CHECKPOINT: CKP-{MSN_id}-{SEQ} — {Checkpoint Name}

**Mission:** MSN-{id} — {Mission Title}  
**Session:** {date} | **EA / Project:** {EA name}  
**Previous CKP:** CKP-{prev_id} | **Next CKP:** CKP-{next_id}

---

## ENTRY CRITERIA (โหลดก่อนเริ่ม session)

> ส่ง 3 สิ่งนี้ให้ James ต้น session แทนการเล่า context ยาว

- [ ] Context_Summary ของ EA นี้ (version ล่าสุด)
- [ ] KB / SKILL ที่เกี่ยวข้อง: {ระบุ}
- [ ] Previous CKP output verified: CKP-{prev_id}

**Prompt เปิด session:**
```
James — อ่าน [ชื่อไฟล์ Context_Summary] แล้วครับ
Checkpoint วันนี้: CKP-{id} — {ชื่อ}
วันนี้จะทำ: [ระบุงาน]
```

---

## TODAY'S GOAL

> {เป้าหมายของ session นี้ — ชัดเจน ไม่กว้าง}

**Definition of Done:**
- [ ] {เงื่อนไขที่ถือว่า session นี้สำเร็จ #1}
- [ ] {เงื่อนไขที่ถือว่า session นี้สำเร็จ #2}
- [ ] {เงื่อนไขที่ถือว่า session นี้สำเร็จ #3}

**Out of Scope วันนี้:** {สิ่งที่ไม่ทำ — ป้องกัน scope drift}

---

## TASK BREAKDOWN

| # | Task | Output | Done |
|---|------|--------|------|
| 1 | {task} | Code / Decision / Test | ⬜ |
| 2 | {task} | Code / Decision / Test | ⬜ |
| 3 | {task} | Code / Decision / Test | ⬜ |

---

## EXIT CRITERIA (ก่อนปิด session — พิมพ์ `/summary`)

- [ ] ทุก Task มี output ชัดเจน
- [ ] Context_Summary.md อัปเดตแล้ว (version ใหม่)
- [ ] Key decisions บันทึกพร้อม rationale
- [ ] Remaining steps สำหรับ CKP ถัดไประบุชัด
- [ ] Memory อัปเดตถ้ามี key learning ใหม่

---

## SESSION SUMMARY
*(James generate ให้เมื่อพิมพ์ `/summary` หรือ `/checkpoint done`)*

### Completed
| Task | Output | หมายเหตุ |
|------|--------|---------|
| | | |

### Key Decisions / Learnings
1. {decision/learning} — เพราะ {rationale}

### Carry-over → Next Session
- {สิ่งที่ยังค้างอยู่}

### Next CKP Prep
**โหลดสิ่งเหล่านี้:**
- Context_Summary: {ชื่อไฟล์ version ใหม่}
- First task: {ระบุงานแรกชัดเจน — ไม่ใช่ "ต่อจากเดิม"}

---

*Template version: 1.0 | 2026-08-30 | ใช้คู่กับ Context_Summary.md*
