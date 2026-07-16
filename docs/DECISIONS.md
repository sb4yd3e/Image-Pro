# Decision log

## ADR-001 — Native macOS application

- Date: 2026-07-15
- Status: Accepted
- Decision: SwiftUI + AppKit และแยก core เป็น Swift package
- Reason: integration กับ file system, Core Image, Vision และ Core ML โดยตรง พร้อม footprint ต่ำกว่า Electron/Python bundle
- Consequence: เน้น Apple Silicon และไม่ทำ cross-platform

## ADR-002 — Offline by architecture

- Date: 2026-07-15
- Status: Accepted
- Decision: ไม่มี network dependency ใน processing path; model import จาก local disk
- Reason: privacy และใช้งานได้จริงโดยไม่พึ่ง service
- Consequence: ผู้ใช้ต้องจัดหา/import model resources เองในรุ่นแรก

## ADR-003 — Provider protocols

- Date: 2026-07-15
- Status: Accepted
- Decision: UI และ operation graph ใช้ app-owned image/mask types และ provider protocols
- Reason: เปลี่ยน Vision/Core ML/ncnn provider ได้โดยไม่แก้ editor
- Consequence: ต้องมี conversion boundary และ contract tests เพิ่ม

## ADR-004 — Native image stack first

- Date: 2026-07-15
- Status: Accepted
- Decision: Core Image + ImageIO เป็น default; เพิ่ม encoder เฉพาะเมื่อ benchmark ยืนยันความจำเป็น
- Reason: ลด dependency และได้ color/metadata integration ที่ดี
- Consequence: WebP/AVIF และ compression สูงสุดอาจมาภายหลัง

## ADR-005 — Vision for MVP background removal

- Date: 2026-07-15
- Status: Accepted
- Decision: Apple Vision เป็น default และ BiRefNet เป็น optional quality spike
- Reason: ไม่มี model setup และรองรับ instance mask
- Consequence: ต้องมี manual refine และ regression test ข้าม OS revision

## ADR-006 — Core ML Real-ESRGAN subject to spike

- Date: 2026-07-15
- Status: Accepted for personal build
- Decision: ใช้ RealESRGAN-x4plus Core ML แบบ fixed 256→1024 แล้วประกอบ central overlap tiles รองรับ output 2×/4×
- Alternative: ncnn-vulkan CLI
- Trigger to revisit: Core ML output ต่างจาก reference มาก, ช้าเกินไป หรือ memory สูงเกินงบ

## ADR-007 — LaMa before generative fill

- Date: 2026-07-15
- Status: Accepted
- Decision: Quick Remove ด้วย LaMa มาก่อน Stable Diffusion
- Reason: model เล็กกว่า เร็วกว่า และไม่ต้อง prompt สำหรับงานลบวัตถุทั่วไป
- Consequence: Quick Remove กับ Generative Fill เป็นสอง tool mode แม้ใช้ mask engine ร่วมกัน

## ADR-008 — Bundle WebP encoder statically

- Date: 2026-07-15
- Status: Accepted
- Context: ImageIO บนเครื่องเป้าหมายอ่าน WebP ได้แต่ไม่มี destination encoder
- Decision: ฝัง libwebp 1.6.0 ที่ build สำหรับ arm64/macOS 14 และเรียกผ่าน C bridge; ใช้ ImageIO สำหรับ decode
- Alternatives: เรียก `cwebp` ภายนอก, บังคับติดตั้ง Homebrew หรือรอ ImageIO รองรับ encode
- Consequences: export WebP ทำงาน offline แบบ self-contained และรองรับ lossy/lossless/alpha แต่ไฟล์ output ปัจจุบันไม่เก็บ metadata เดิม

## ADR-009 — Bundle LaMa and Stable Diffusion model resources

- Date: 2026-07-15
- Status: Accepted for personal build
- Context: ผู้ใช้ต้องการเปิดแอปแล้วใช้งาน offline ทันทีและไม่ต้องสนใจขนาด package เพื่อจำหน่าย
- Decision: ฝัง LaMa 6-bit Core ML และ Stable Diffusion 1.5 compiled resources ใน `.app`; ใช้ Apple `ml-stable-diffusion` 1.1.1, `reduceMemory` และ unload หลังจบงาน
- Consequences: release app ประมาณ 2.1 GB แต่ Erase, Generative Fill และ Outpaint ไม่ต้องดาวน์โหลดอะไรตอนใช้งาน

## ADR-010 — Autosave complete local snapshots

- Date: 2026-07-15
- Status: Accepted
- Decision: autosave source, editing base, active render, operation graph และ mask เป็น package ใน Application Support แบบ atomic
- Reason: AI render ไม่สามารถสร้างซ้ำได้รวดเร็วและ source path อาจถูกย้าย การเก็บ snapshot ทำให้ recovery เชื่อถือได้กว่าเก็บ operation อย่างเดียว
- Consequences: autosave ใช้พื้นที่เพิ่มใกล้เคียง 2–3 เท่าของภาพที่เปิดล่าสุด

## ADR template

```text
## ADR-NNN — Title
- Date:
- Status: Proposed / Accepted / Superseded
- Context:
- Decision:
- Alternatives:
- Consequences:
- Trigger to revisit:
```
