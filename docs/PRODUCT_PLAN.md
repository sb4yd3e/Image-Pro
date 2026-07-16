# Product plan

ปรับปรุงล่าสุด: 2026-07-15

## 1. เป้าหมาย

Image Pro เป็นแอป macOS สำหรับแก้ไขและ optimize ภาพแบบ offline โดยให้ผู้ใช้ทำงานที่พบบ่อยได้ภายใน 1–3 คลิก และเปิด editor เฉพาะเมื่อต้องเลือกพื้นที่หรือแก้ mask

### เป้าหมายหลัก

- ลบพื้นหลังและแก้ขอบ mask ได้
- Crop, rotate, flip, resize และเปลี่ยน canvas
- ลดขนาดไฟล์และแปลง format โดยคาดเดาค่าที่เหมาะสมให้
- AI upscale แบบ 2x/4x โดยรองรับภาพใหญ่ผ่าน tile
- ระบายเพื่อลบวัตถุแล้วเติมฉากหลัง
- ระบายพื้นที่และใช้ prompt เพื่อสร้างสิ่งใหม่ในพื้นที่นั้น
- ทำงานหลายไฟล์ผ่าน batch queue
- ไม่อัปโหลดรูปหรือ prompt ออกจากเครื่อง

### ไม่อยู่ใน MVP

- Layer editor เต็มรูปแบบแบบ Photoshop
- RAW development ระดับ Lightroom
- Video editing
- Cloud sync, account, subscription และ collaboration
- Training หรือ fine-tuning model ภายในแอป
- Intel Mac optimization

## 2. ผู้ใช้และงานหลัก

ผู้ใช้หลักคือเจ้าของเครื่องที่ต้องการจัดการรูปสำหรับเว็บ งานเอกสาร โซเชียล และงานส่วนตัว โดยไม่ต้องเปิดโปรแกรมขนาดใหญ่หรือส่งรูปขึ้นเว็บ

### Core jobs

1. “ทำรูปนี้ให้เล็กพอส่งหรือขึ้นเว็บ แต่ยังดูดี”
2. “เอาพื้นหลังออกแล้วได้ PNG โปร่งใส”
3. “ขยายรูปเล็กให้ชัดขึ้น”
4. “ลบคน สายไฟ ฝุ่น หรือข้อความออก”
5. “เติมหรือขยายส่วนของภาพด้วยคำสั่ง”
6. “ทำแบบเดียวกันกับรูปทั้งโฟลเดอร์”

## 3. Information architecture

### หน้า Home

- Drop zone
- Recent projects
- Quick Actions: Optimize, Remove Background, Resize, Upscale, Open Editor
- Batch Queue summary

### หน้า Editor

- Toolbar ด้านบน: Import, Undo/Redo, Compare, Export
- Tool rail ด้านซ้าย: Select, Crop, Resize, Remove BG, Erase, Generative Fill, Upscale, Optimize
- Canvas ตรงกลาง
- Inspector ด้านขวา
- Job/progress bar ด้านล่าง

### Model Manager

- แสดง model ที่ติดตั้ง ขนาด ตำแหน่ง และสถานะ validation
- Import model package จาก disk
- Remove model
- ไม่มี auto-download เป็น requirement ของ MVP; การดาวน์โหลดเป็น helper ภายหลังได้

## 4. Feature requirements

### F-01 Import และ project

- รองรับ drag-and-drop, Open dialog และ paste จาก clipboard
- เปิด JPEG, PNG, HEIC, TIFF และ WebP ที่ระบบ decode ได้
- เก็บ orientation และ color profile อย่างถูกต้อง
- สร้าง project state โดยไม่แก้ source file
- Recover งานหลังแอปปิดผิดปกติ

Acceptance:

- เปิดภาพ 24 MP ได้โดย UI ไม่ค้างนานเกิน 500 ms; decode เต็มทำ background ได้
- Undo/Redo อย่างน้อย 50 operations
- Source checksum ไม่เปลี่ยนจนกว่าผู้ใช้เลือก overwrite โดยชัดเจน

### F-02 Crop / Resize / Canvas

- Free crop และ preset 1:1, 4:5, 3:2, 16:9
- Resize ด้วย pixel, percent และ long edge
- Fit, Fill, Stretch และ Canvas extension
- Rotate 90°, arbitrary straighten และ flip
- Preset สำหรับ Web, Social และ custom saved preset

Acceptance:

- Preview เปลี่ยนตามค่าภายใน 100 ms สำหรับ proxy image
- Lock aspect ratio ทำงานสม่ำเสมอเมื่อแก้ width หรือ height
- Export dimension ตรงตามค่าที่กำหนดทุกครั้ง

### F-03 Smart Optimize

- Preset: Best Quality, Balanced, Small File, Web, Lossless, Target Size, Metadata Only
- Format: Auto, JPEG, PNG, HEIC, WebP; AVIF เป็น optional phase
- ลบ EXIF/IPTC/XMP/GPS ทั้งหมดหรือเก็บเฉพาะรายการที่เลือก
- Convert เป็น sRGB หรือรักษา embedded profile
- ข้ามผลลัพธ์ถ้าไฟล์ใหม่ใหญ่กว่าเดิม
- แสดง original size, estimated size และ actual size
- Target Size มี preference: Preserve Quality, Preserve Resolution, Auto

Target-size algorithm:

1. Encode ที่ quality สูงสุดของ preset
2. ใช้ binary search หา quality ที่อยู่ใต้เป้าหมาย
3. ถ้ายังใหญ่เกิน lower quality bound ให้ลด long edge ทีละช่วง
4. Encode รอบสุดท้ายและตรวจ byte count จริง
5. แจ้ง warning หาก SSIM proxy หรือ quality ต่ำกว่า threshold ที่กำหนด

Acceptance:

- Output ไม่เกิน target มากกว่า 2% เมื่อ encoder รองรับ lossy quality
- Metadata removal test ต้องไม่พบ GPS/EXIF ที่เลือกเอาออก
- Batch 100 ไฟล์ยกเลิกกลางงานได้และไม่ทิ้งไฟล์เสีย

### F-04 Background Removal

- One-click foreground detection
- รองรับหลาย instance และเลือก instance จาก click
- แสดง mask overlay
- Brush Keep/Remove, edge feather, contract/expand และ decontaminate edge
- Export alpha PNG/WebP

Acceptance:

- ใช้ Apple Vision เป็น default path
- Hair/fur edge มี manual refinement ที่ใช้งานได้แม้ automatic mask ไม่สมบูรณ์
- ไม่เกิดขอบดำจาก premultiplied alpha ใน export

### F-05 AI Upscale

- 2x และ 4x
- Photo และ Illustration/Anime model
- Tile inference พร้อม overlap และ feather blend
- Optional final resize สำหรับขนาดที่ไม่ใช่จำนวนเต็ม
- Preview เฉพาะ viewport ก่อนรันเต็มภาพ

Acceptance:

- Tile seam มองไม่เห็นในการทดสอบ gradient, texture และเส้นทแยง
- Peak memory อยู่ในงบที่กำหนดใน Test Plan
- Cancel แล้วคืน memory/model resources ภายในเวลาที่เหมาะสม

### F-06 Object Removal

- Brush mask พร้อมปรับขนาด hardness และ opacity
- Quick Remove ไม่ต้องใช้ prompt
- Auto-expand context รอบ mask
- Preview result และ Generate Again
- Feather composite กลับสู่ภาพความละเอียดเต็ม

Acceptance:

- ลบวัตถุขนาดเล็กถึงกลางได้โดยไม่ลด resolution ทั้งภาพ
- Mask stroke undo/redo แยกจากการรัน model
- สร้างผลใหม่ไม่เขียนทับผลก่อนจนกด Apply

### F-07 Generative Fill / Outpaint

- Prompt, negative prompt, seed, strength และ step preset
- ใช้ mask เดียวกับ Object Removal
- Generate 1–4 variants
- Extend canvas แล้วสร้างบริเวณนอกภาพ
- Model unload และ low-memory mode

Acceptance:

- ทำงานแบบ offline หลังนำเข้า model resources แล้ว
- ยกเลิก generation ได้
- Seed เดิมและค่าตั้งเดิมต้องให้ผลซ้ำได้ภายใต้ model/runtime เดียวกัน

### F-08 Batch Queue

- Add files/folder
- Apply operation preset
- Output folder, naming template และ collision policy
- Pause, resume, cancel และ retry failed jobs
- Summary: input bytes, output bytes, saved bytes, elapsed time

Acceptance:

- Queue state recover ได้หลัง relaunch
- เขียนผ่าน temporary file แล้ว atomic move เท่านั้น
- Failure ของไฟล์หนึ่งไม่หยุดทั้ง queue

## 5. Non-functional requirements

- Offline: ไม่มี network request ใน processing path
- Privacy: ลบ GPS เป็น default ของ Web/Small File preset
- Responsiveness: งานเกิน 100 ms ต้องไม่รันบน main actor
- Reliability: export แบบ temp + atomic rename
- Memory: ใช้ proxy สำหรับ canvas และ full-resolution เฉพาะ export/AI crop
- Accessibility: keyboard navigation, VoiceOver labels และ contrast ตาม macOS conventions
- Recovery: autosave operation graph และ queue ทุกครั้งที่ state เปลี่ยนสำคัญ
- Observability: local log ที่ไม่เก็บ pixel, path เต็ม หรือ prompt ถ้าไม่ได้เปิด debug mode

## 6. UX rules

- ทุก tool ต้องมีค่า Recommended ที่กด Apply ได้ทันที
- Advanced settings ถูกซ่อนโดย default
- Preview ไม่ควรเปลี่ยน source file
- AI result เป็น draft จนกด Apply
- ปุ่ม Export แสดง format, dimension และ estimated size โดยไม่ต้องเปิด dialog เพิ่ม
- Warning ต้องบอกผลกระทบและทางแก้ เช่น “โมเดลนี้ต้องใช้หน่วยความจำเพิ่มประมาณหลาย GB”

## 7. Definition of MVP done

- Quick Optimize, crop/resize, background removal และ 4x upscale ทำงานครบ
- Batch optimize อย่างน้อย JPEG/PNG/HEIC
- Crash-free 50 consecutive operations ใน test session
- Golden-image tests ผ่านตาม tolerance
- ใช้งานได้โดยปิด Wi-Fi หลัง import model
- README และวิธีติดตั้ง model เขียนครบ
