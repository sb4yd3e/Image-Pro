# Project status

ปรับปรุงล่าสุด: 2026-07-16

## Current state

- Overall: Usable offline personal build; lightweight app, external Model Manager and GitHub Release OTA implemented
- Active phase: hardening/real-image benchmark หลัง implementation Phase 1–5
- Reference machine: MacBook Pro M1 Pro 10-core, RAM 32 GB, macOS 26.5.2
- Blockers: ไม่มี blocker สำหรับการใช้งานส่วนตัวบนเครื่องอ้างอิง
- Decisions pending: SAM 2.1, PaddleOCR-VL และ FLUX.2 Klein provider หลัง runtime/quality benchmark

## Completed

- [x] กำหนด product scope และ offline principles
- [x] Research native Apple stack และ reusable AI projects
- [x] กำหนด architecture/provider boundaries
- [x] สร้าง phased roadmap, backlog และ test plan
- [x] กำหนด UI direction และ mockup brief
- [x] สร้าง Swift package: core library, macOS app, capability-probe CLI และ tests
- [x] สร้าง `.app` bundle แบบ ad-hoc signed และเปิดใช้งานจริง
- [x] Import ผ่าน file picker/drag-and-drop และ render ภาพบน canvas
- [x] Optimize JPEG/PNG/HEIC/AVIF ตาม runtime capability, resize และ target bytes
- [x] Metadata policy, atomic export และ batch optimizer core
- [x] Operation graph, project package, model manifest/checksum และ queue state core
- [x] Vision foreground provider และ Remove Background action ใน app
- [x] Core tests 65/65 ผ่าน ครอบคลุม Model Store/ZIP import, inference โมเดลจริง, OCR, batch recipe, Vision fallback และ golden-image regression
- [x] WebP lossy/lossless/alpha/target-size ผ่าน static libwebp 1.6.0 โดยไม่ต้องพึ่ง Homebrew runtime
- [x] Crop preset/free, Resize Fit/Fill/Stretch, Rotate/Flip เชื่อมกับ operation graph แบบ non-destructive
- [x] Undo/Redo/Revert และ Before/After segmented toggle ทำงานใน UI จริง
- [x] Metadata round-trip ยืนยันการลบ GPS และ EXIF private fields หลัง encode/read กลับ
- [x] เปิดไฟล์จาก Finder ตอน cold launch และจำกัด app เป็นหน้าต่างหลักเดียว
- [x] Auto format classifier, collision policy และ persistent Batch Queue พร้อม cancel/relaunch recovery
- [x] Recent files, autosave/restore project snapshot และ Before/After Split
- [x] Remove BG edge controls + transparent/color/blur background
- [x] Real-ESRGAN Core ML tile inference รองรับ 2×/4×
- [x] Mask brush, LaMa context crop และ composite เฉพาะ mask
- [x] Stable Diffusion Core ML masked fill, seed/variants, low-memory unload และ Outpaint
- [x] Image-processing core scan ยืนยันไม่มี network client API; updater แยกเป็น app-only opt-in boundary
- [x] Release app 2.1 GB ฝัง LaMa, Real-ESRGAN และ Stable Diffusion; ad-hoc codesign verify ผ่าน
- [x] เพิ่มปุ่ม Export บน toolbar + `⌘E` และทดสอบเขียนไฟล์ผ่าน Save panel จริง
- [x] แก้ Split ให้ภาพ Before/After ใช้ fitted rect เดียวกันและ divider ไม่ออกนอกขอบภาพ
- [x] แก้ Remove BG ที่ส่ง instance set ว่างให้ Vision จนภาพหาย พร้อม regression test จากภาพจริง
- [x] เพิ่ม Crop แบบลากกรอบ/ย้าย/ย่อขยายด้วย handle บน canvas และ preset aspect ratio
- [x] ทดสอบ UI จริงสำหรับ Crop, Resize, Remove BG, Upscale, Erase, Generate, Undo และ Export
- [x] แก้ Real-ESRGAN short-tile origin ที่ทำให้เกิดแถบภาพยืด และรักษา alpha หลัง upscale
- [x] เพิ่ม canvas Zoom/Fit/Pan และ preview proxy จำกัด 2,048 px โดย operation/export ยังใช้ข้อมูลเต็มความละเอียด
- [x] เพิ่ม Remove BG แบบสองขั้น: Detect Subjects, เลือก instance, Keep/Remove brush และ Apply Removal
- [x] เก็บ AI Undo/Redo history ใน autosave project และยืนยันว่ากู้คืนได้หลังปิด/เปิดแอป
- [x] เพิ่ม Reveal in Finder หลัง export, Generate Again และ Batch Add Folder แบบ recursive
- [x] เพิ่ม folder image auditor/JSON report และตรวจชุดจริง 28 ภาพผ่าน 28/28
- [x] แยก Remove BG refinement brush ออกจาก Erase/Generate mask และป้องกัน subtract-only empty mask ที่ทำให้ Core ML error
- [x] เพิ่ม Auto Remove Background แบบ one-click และ Clear Recent history โดยไม่ลบไฟล์จริง
- [x] เพิ่ม Offline OCR ผ่าน Vision พร้อม runtime languages, bounding boxes, editable result, Copy และ TXT export
- [x] เพิ่ม Save/Open `.imagepro`, clipboard image และ Finder Services สำหรับ Optimize/Remove BG
- [x] เพิ่ม Batch Recipe: Auto Remove BG, Resize long edge และ Preserve Folder Structure
- [x] เพิ่ม generation quality presets, memory warning, keyboard tool shortcuts, benchmark และ golden-image harness
- [x] ปรับ toolbar/sidebar/canvas/inspector เป็นแผงมุมโค้งพร้อมระยะ 8–20 pt และรองรับหน้าต่างขั้นต่ำ 1180×720
- [x] เพิ่ม UI ภาษาไทย/อังกฤษแบบเปลี่ยนทันทีจาก toolbar หรือ Settings (`⌘,`) พร้อมบันทึกค่าระหว่างการเปิดแอป
- [x] ป้องกันรูปใหญ่ค้าง UI ด้วย mapped read + bounded preview preparation นอก main actor
- [x] Optimize เป็น preview-before-save, split divider ไม่ scale, trackpad pinch zoom และ sidebar full-row hit area
- [x] บล็อก UI ระหว่าง processing พร้อม Cancel และซ่อน scroll indicators
- [x] เปิดแอปใหม่ด้วย canvas ว่างโดยไม่ auto-restore รูปเดิม
- [x] Smart Erase เพิ่ม adaptive mask expansion/context/feather; Generate เพิ่ม masked prefill/strength tuning และ optional SDXL auto-detection
- [x] GitHub Release OTA ตรวจ SHA-256/bundle/version, release packaging script, README, MIT license และ blueprint App Icon
- [x] แก้ Remove Background สำหรับภาพโปสเตอร์/กราฟิกพื้นเรียบด้วย person, edge-connected และ saliency fallback พร้อมข้อความแนะนำแทน error code 0
- [x] แยก LaMa, Real-ESRGAN และ Stable Diffusion เป็น model pack ภายนอก พร้อม import/download/activate/remove/rollback UI
- [x] ลด release `.app` จากประมาณ 2.1 GB เหลือ 6.6 MB โดยฟีเจอร์แจ้ง Model required และเปิด Model Manager เมื่อยังไม่ติดตั้ง

## Next 5 tasks

1. เก็บ OCR ground truth ไทย/อังกฤษ ทั้งพิมพ์และลายมือเพื่อวัด CER/WER ก่อนตัดสินใจเพิ่ม PaddleOCR
2. ขยายชุด image audit จาก 28 เป็น 100 ภาพและบันทึก failure categories
3. ปิด SP-001 ส่วน HDR/gain-map/orientation fixtures
4. วัด cold/warm AI inference บนภาพ 24 MP และ panorama ด้วย benchmark harness
5. ทำ accessibility/VoiceOver audit แบบ manual

## Risks/watch list

| Risk | Impact | Mitigation | State |
|---|---|---|---|
| Core ML conversion ให้ผลหรือความเร็วไม่ตรง reference | คุณภาพ upscale บางภาพต่ำ | benchmark เทียบ ncnn หลังเก็บชุดภาพจริง | Provider verified |
| Fixed-size LaMa ทำรายละเอียดหาย | Object removal คุณภาพต่ำ | context crop + composite เฉพาะ mask | Open |
| Diffusion memory สูง | app ถูก terminate | phase แยก, unload, low-memory mode | Open |
| ImageIO encode support ต่างตาม OS | format บางชนิดใช้ไม่ได้ | runtime capability probe + libwebp | Open |
| UI ทำ full-resolution ทุก frame | lag/memory spike | proxy + viewport render | Controlled by design |

## Work log

### 2026-07-16

- Hardening รูปใหญ่, zoom/pan/split, sidebar hit target, processing lock และ Optimize preview-before-save
- UI smoke บนภาพ 9,600×6,000 ผ่าน: bounded preview ไม่ดำ/ไม่ค้าง, blocker/Cancel แสดงระหว่างโหลด, zoom 195% แล้วยังกด sidebar ได้, split divider คงความหนา และ Optimize preview 27.5 MB → 5 MB ก่อนเปิด Save panel
- ปรับ LaMa composite และ Stable Diffusion masked generation หลังทบทวน PowerPaint, BrushNet และ Apple SDXL Core ML
- เพิ่ม updater ผ่าน GitHub Releases พร้อม checksum verification และ release packaging
- สร้าง blueprint App Icon แบบโปร่งใสพร้อม `.icns`, อัปเดต README/MIT/license และเอกสารใช้งาน TH/EN
- แก้ VisionForegroundError error 0 จากภาพกราฟิกพื้นเรียบ: เพิ่ม bounded retry และ fallback mask หลายขั้น; ทดสอบภาพที่รายงานจริงแล้วพื้นแดงหาย ตัวอักษร/QR อยู่ครบ และ full suite 61/61 ผ่าน
- เปลี่ยน model lifecycle เป็น external packs: Model Store/manifest/catalog/checksum/compatibility validation, Settings → Models, local import, remote download และ per-feature activation
- สร้างแพ็ก LaMa 36 MB, Real-ESRGAN 30 MB และ Stable Diffusion แยกจากแอป; release app ใหม่ 6.6 MB และ strict codesign ผ่าน
- แก้ Model Catalog HTTP 404 ที่เคยแสดง `NSURLError -1011`: เก็บ HTTP status จริง, แสดงคำแนะนำแทน error ดิบ และ fallback ไป bundled/cached catalog เมื่อออนไลน์ไม่ได้
- ปรับ Settings เป็น content-sized window ตามแท็บ (General 650×418, Models 650×458 เมื่อมีหนึ่งโมเดล), จัดเนื้อหาชิดบน และให้ Manage Models เปิดแท็บ Models โดยตรง

### 2026-07-15

- เริ่ม repository documentation
- Research Core Image, ImageIO, Vision, Core ML Stable Diffusion, Real-ESRGAN, LaMa, BiRefNet, IOPaint และ image optimization codecs
- เลือก native modular architecture
- ตั้ง Phase 0 spikes เพื่อยืนยัน model/runtime ก่อน implementation
- เพิ่มโค้ด foundation และเปิด app bundle จริงสำเร็จ
- Runtime probe ยืนยันว่า ImageIO อ่าน WebP ได้แต่เขียนไม่ได้; AVIF เขียนได้บนเครื่องนี้
- เพิ่ม bundled WebP encoder เนื่องจาก ImageIO ไม่มี WebP destination; pipeline รองรับ Optimize/Target Size/Batch แล้ว
- ทดสอบ import PNG 1,586×992 ใน UI จริงและยืนยัน Export ถูก enable
- เพิ่ม Crop/Resize/Rotate/Flip inspector และเชื่อม operation graph พร้อม Undo/Redo
- ทดสอบ UI จริง: crop 1:1 จาก 1,586×992 เป็น 992×992, Undo/Redo และ Before/After ผ่าน
- เพิ่ม metadata encode/read-back tests และใช้ source metadata เดิมตอน export ภาพที่แก้ไข
- แก้เปิดภาพจาก Finder ตอน cold launch และเปลี่ยนเป็น single main window
- เพิ่ม Auto format, persistent batch queue, collision handling, recent files และ autosave project snapshot
- ฝังและทดสอบ Real-ESRGAN-x4plus กับ LaMa Core ML ด้วย inference จริง
- ฝัง Stable Diffusion 1.5 resources และทดสอบ local generation จริง
- เพิ่ม mask brush, Erase, Generative Fill, variants, Outpaint, cancel และ low-memory unload
- เพิ่ม Remove BG feather/edge/background presets, upscale 2×/4×, straighten และ split comparison
- ชุดทดสอบเดิม 45/45 ผ่านใน 16.0 วินาที; release build/codesign/launch smoke ผ่าน
- Hardening จาก UI audit: แก้ Export discovery, Split geometry, Vision empty instances, Crop DnD, AI Undo/Redo, Generate preview mask, cancel state และ Real-ESRGAN short-tile/alpha
- เพิ่ม Vision, Batch และ Core ML regression tests; ชุดล่าสุด 49/49 ผ่านใน 22.6 วินาที
- เพิ่ม large-image proxy, Zoom/Pan, Remove BG instance/refine, persisted AI history, Reveal, Generate Again และ recursive folder import
- เพิ่ม image-folder audit CLI; ชุดตัวอย่าง 28/28 ผ่าน และชุดทดสอบล่าสุด 52/52 ผ่านใน 23.1 วินาที
- แก้ Erase/Generate empty-mask regression, แยกสถานะแปรงและเพิ่ม human-readable AI errors; ชุดล่าสุด 53/53 ผ่านใน 19.6 วินาที
- เพิ่ม OCR offline + ผลวิจัย multilingual/handwriting, `.imagepro` project, clipboard, Finder Services, Batch Recipe, quality/memory UX และ QA harness
- Full suite 59/59 ผ่านใน 24.8 วินาที; release bundle build และ strict codesign verification ผ่าน
- แก้ numeric fields ให้ update ทันที และเพิ่ม regression ยืนยัน Batch Auto Remove BG + Resize 800 px
- ลงทะเบียนและเรียก Finder Services จริงสำเร็จทั้ง Optimize และ Auto Remove Background
- ปรับ visual spacing/panel hierarchy และเพิ่ม Localizable.strings ภาษาไทย/อังกฤษ; ตรวจ UI จริงทั้ง Optimize, Crop, OCR และ Settings ที่ 1180×752 โดยข้อความไทยไม่ล้น

## Update template

```text
### YYYY-MM-DD
- Doing:
- Done:
- Blocked:
- Evidence/benchmark:
- Decision changed:
- Next:
```
