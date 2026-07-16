# Known issues

ปรับปรุงล่าสุด: 2026-07-16

- Real-ESRGAN model ที่เลือกต้องใช้ macOS 15+; ส่วนอื่นของแอปตั้งเป้า macOS 14+
- model pack มาตรฐานยังเป็น Stable Diffusion v1.5 ที่ context 512×512; pipeline ใหม่ prefill พื้นที่ mask, ลด strength และ feather ขอบแล้ว แต่ข้อความ มือ ใบหน้า และ outpaint ใหญ่อาจยังไม่สม่ำเสมอ แอปจะใช้ SDXL 1024 อัตโนมัติเมื่อพบ optional Core ML pack ที่ครบ
- Remove Background ใช้ Vision ก่อน แล้ว fallback เป็น person segmentation, edge-connected background และ saliency สำหรับภาพที่ไม่มี subject instance เช่นโปสเตอร์พื้นเรียบ; ขอบผม วัตถุโปร่งใส หรือพื้นหลังหลายสีอาจยังต้องใช้ Detect & Refine/Keep/Remove brush ร่วมกับ feather/edge shift
- Smart Erase ยังใช้ LaMa เป็น native backend แต่เพิ่ม adaptive mask expansion, context 2.75× และ edge feather แล้ว เหมาะกับวัตถุเล็กถึงกลาง; บริเวณใหญ่มากอาจยังสร้าง texture ซ้ำ โดย PowerPaint/BrushNet เป็น candidate รอบ model pack ถัดไป
- Upscale 4× ทำให้จำนวนพิกเซลเพิ่ม 16 เท่า ภาพต้นฉบับใหญ่อาจใช้ RAM สูง ควรเริ่ม 2×
- WebP export ไม่เก็บ metadata เดิม ส่วน JPEG/PNG/HEIC/TIFF ใช้ metadata policy ของ Optimize
- OCR ใช้ภาษาที่ Apple Vision บน macOS รุ่นนั้นรองรับและไม่รับประกันลายมือทุกแบบ ควรตรวจแก้ผลก่อนใช้; PaddleOCR เป็น optional provider หลังมี CER/WER benchmark
- ยังไม่มี Photo/Anime model switch, BiRefNet fallback และ import model ผ่าน UI; เป็น optional enhancement ไม่ขวาง workflow หลัก
- Finder Services อาจปรากฏหลัง LaunchServices refresh หรือเปิดแอปหนึ่งครั้ง และตำแหน่งเมนูขึ้นกับการตั้งค่า Extensions/Services ของ macOS
- ยังต้องทำ visual benchmark กับชุดภาพจริง 30/100 ภาพและทดสอบเครื่อง RAM ต่ำก่อนถือเป็น release สำหรับผู้อื่น
