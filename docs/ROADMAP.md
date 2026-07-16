# Roadmap

สถานะ: `Not started` / `In progress` / `Blocked` / `Done`

## Phase 0 — Foundation and spikes

เป้าหมาย: ตัดความเสี่ยงทางเทคนิคก่อนสร้าง UI เต็ม

- [x] สร้าง Xcode workspace และ `ImageProCore` Swift package
- [ ] SP-01 ตรวจ format/metadata matrix ของ ImageIO — codec matrix เสร็จ, metadata/HDR ยังเหลือ
- [ ] SP-02 สร้าง Vision foreground mask CLI/sample — provider + app action เสร็จ, benchmark set ยังเหลือ
- [x] SP-03 ทดสอบ Real-ESRGAN Core ML + tile assembly บน model จริง
- [x] SP-04 ทดสอบ LaMa Core ML context crop บน model จริง
- [x] SP-05 ทำ target-size encoder prototype
- [ ] สร้าง benchmark image set และเก็บ expected outputs

Exit criteria:

- เลือก model files จริงสำหรับ upscale และ LaMa ได้
- ทราบ memory/time บนเครื่องเป้าหมาย
- export JPEG/PNG/HEIC พร้อม metadata policy ผ่าน test
- ไม่มี blocker ที่บังคับให้ฝัง Python runtime

## Phase 1 — Useful local image utility

เป้าหมาย: เปิด แก้ขนาด optimize และ batch ได้จริงโดยยังไม่พึ่ง AI

- [x] Home drop zone และ recent files
- [x] Project document + autosave/restore snapshot
- [ ] Canvas proxy rendering
- [x] Crop/resize/rotate 90°/flip + operation graph + undo/redo
- [x] Straighten และ canvas expansion ผ่าน Outpaint
- [x] Optimize presets และ target size
- [x] Export summary + atomic write
- [x] Persistent Batch queue + cancel/relaunch recovery
- [x] Before/After แบบ segmented toggle
- [x] Before/After แบบ split view พร้อม draggable divider

Exit criteria:

- ใช้กับรูปจริงอย่างน้อย 100 ไฟล์โดยไม่ทำ source เสีย
- Target Size และ metadata acceptance tests ผ่าน
- UI ไม่ค้างระหว่าง batch/export

## Phase 2 — Remove background and upscale

- [x] Apple Vision foreground provider
- [x] Mask overlay สำหรับ Erase/Generate; instance picker ยังเป็น optional enhancement
- [x] Keep/Remove mask brush + edge controls
- [x] Transparent composite/export validation
- [x] Real-ESRGAN provider
- [x] Overlap tile assembly; viewport preview ยังเป็น optional enhancement
- [ ] Photo/Anime model selection
- [x] Batch Auto Remove BG + Resize recipe และ preserve folder structure

Exit criteria:

- ชุดทดสอบ 30 ภาพมีผลที่ใช้งานได้หรือแก้ด้วย brush ได้
- Upscale ไม่มี visible seam
- Memory pressure ไม่ทำให้ project เสีย

## Phase 3 — Object removal

- [x] Mask brush engine + normalized strokes/undo
- [x] LaMa provider
- [x] Context crop planner
- [x] Feather composite
- [x] Variant/Apply/Discard draft flow สำหรับ Generative tool
- [x] Composite เฉพาะ mask; visual golden set ระยะยาวยังต้องเพิ่ม

Exit criteria:

- ลบวัตถุเล็ก/กลางใน photo test set ได้
- Undo stroke และ undo applied result ทำงานถูกต้อง

## Phase 4 — Generative fill and outpainting

- [x] Bundled model manifests/notices และ checksum validation core; import UI ไม่จำเป็นสำหรับ personal build
- [x] Stable Diffusion provider
- [x] Prompt/negative prompt/seed
- [x] Variant filmstrip
- [x] Low-memory mode/model unload
- [x] Outpaint canvas workflow
- [x] SP-06 inference smoke benchmark; peak-RSS benchmark ยังต้องเก็บเพิ่ม

Exit criteria:

- Inpainting ทำงาน offline เต็มรูปแบบ
- Cancel และ recovery ไม่ทำ project เสีย
- model missing/incompatible state อธิบายได้ชัดเจน

## Phase 5 — Polish

- [x] Finder Services: Optimize และ Auto Remove Background
- [x] Offline OCR workflow ผ่าน Vision
- [ ] OCR CER/WER benchmark และ optional PaddleOCR provider เมื่อมีหลักฐานว่าจำเป็น
- [ ] Keyboard shortcuts และ accessibility audit (manual audit ยังเหลือ)
- [x] WebP native codec adapter (bundled static libwebp 1.6.0)
- [ ] MozJPEG/pngquant comparison และ adoption ตาม benchmark
- [x] AVIF ผ่าน ImageIO เมื่อ runtime รองรับ
- [x] Queue/project crash recovery; large-image tuning ยังทำต่อได้
- [x] User guide ใน repository

## Release checklist สำหรับแต่ละ phase

- [x] Unit/integration tests ผ่าน (53 tests บน reference machine)
- [ ] Golden image tests ผ่าน
- [ ] Manual smoke test บน clean user account
- [x] Runtime source architecture test: ไม่มี network client API
- [ ] Memory test บนภาพใหญ่
- [x] Documentation และ STATUS อัปเดต
- [x] Known issues ถูกบันทึก
