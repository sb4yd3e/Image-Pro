# Image Pro — User guide

## เริ่มใช้งาน

เปิด `dist/Image Pro.app` แล้วลากรูปลงกลางหน้าต่าง กด Open หรือเปิดรูปจาก Finder ด้วย Image Pro แอปจะไม่เขียนทับต้นฉบับ การแก้ไขถูกเก็บเป็น autosave สำหรับ recovery แต่เมื่อเปิดแอปใหม่ canvas จะเริ่มว่าง ไม่ค้างรูปจากครั้งก่อน

ใช้เมนู **Project > Save Project** หรือ `⌘S` เพื่อเก็บรูปปัจจุบัน operation history และ AI undo/redo เป็น package `.imagepro` ครั้งแรกจะถามตำแหน่ง หลังจากนั้น `⌘S` บันทึกทับ project เดิม; ใช้ **Save Project As…** หรือ `⇧⌘S` เมื่อต้องการสำเนาใหม่ เปิดกลับด้วย **Open Project…** หรือ `⇧⌘O` ได้ นอกจากนี้วางรูปจาก clipboard ด้วย `⌥⌘V` และคัดลอกรูปปัจจุบันด้วย `⇧⌘C`

## เปลี่ยนภาษาไทย/อังกฤษ

กดปุ่มรูปโลก **EN/TH** ที่มุมขวาบนแล้วเลือก English หรือ Thai อินเทอร์เฟซจะเปลี่ยนทันทีโดยไม่ต้องเปิดแอปใหม่ อีกทางหนึ่งกด `⌘,` เพื่อเปิด **Language & Appearance** แล้วเลือกภาษาจากปุ่มแบบแบ่งส่วน การตั้งค่านี้ถูกจำไว้สำหรับครั้งถัดไปและไม่เปลี่ยนข้อมูลในรูปหรือโปรเจกต์

## ติดตั้งโมเดล AI

แอปไม่ฝังโมเดลขนาดใหญ่ไว้ในตัวโปรแกรม กด `⌘,` แล้วเลือกแท็บ **Models** จากนั้นใช้ **Check Catalog** เพื่อดูแพ็กที่ดาวน์โหลดได้ หรือ **Import Model Pack…** เพื่อติดตั้ง ZIP/โฟลเดอร์ `.imagepromodel` จากเครื่อง แอปตรวจ OS, RAM, entrypoint และ checksum ของไฟล์ที่ดาวน์โหลดก่อนติดตั้ง

แต่ละฟีเจอร์เลือกโมเดล Active ได้แยกกัน รุ่นเดิมยังอยู่เพื่อสลับกลับได้จนกดลบ โมเดลเก็บที่ `~/Library/Application Support/Image Pro/Models/` หลังติดตั้งแล้ว Erase, Upscale และ Generate ทำงานออฟไลน์ตามปกติ หากยังไม่มีโมเดล เครื่องมือจะแสดง **Model required** และลิงก์ **Manage Models**

## Export ผลลัพธ์

กดปุ่ม **Export…** สีน้ำเงินบน toolbar หรือกด `⌘E` เพื่อเปิด Save panel และบันทึกผลปัจจุบัน แอปเลือก JPEG/PNG ให้อัตโนมัติตามเนื้อภาพและ alpha หากต้องการเลือก WebP, HEIC, TIFF, quality, target size หรือการย่อภาพ ให้เข้า **Optimize** ตั้งค่าแล้วกด **Optimize** ก่อน แอปจะแปลงเป็น preview โดยยังไม่บันทึก เพื่อให้ตรวจ Before/After และขนาดไฟล์จริง จากนั้นกด Export เมื่อต้องการเขียนไฟล์

เมื่อ export สำเร็จ ใช้ปุ่มรูปโฟลเดอร์บน status bar หรือ **Reveal in Finder** ใน Optimize เพื่อเปิดตำแหน่งไฟล์ล่าสุด

## เครื่องมือ

- **Optimize** เลือก preset/format/quality หรือ Target Size แล้วกด Optimize เพื่อ preview; Auto เลือก PNG สำหรับ alpha/กราฟิกแบน และ JPEG สำหรับภาพถ่าย
- **Batch Queue** ใช้ Add Images หรือ Add Folder เพื่อเพิ่มรูปแบบ recursive เลือกโฟลเดอร์ปลายทาง นโยบายชื่อซ้ำ และกด Run Batch; เปิด Preserve Folder Structure เพื่อคง subfolder และตั้ง Recipe ให้ Resize long edge หรือ Auto Remove Background ก่อน optimize ได้
- **Crop & Resize** เลือก Free/1:1/4:3/16:9 แล้วลากสร้างกรอบบนภาพ ลากด้านในเพื่อย้าย หรือลาก handle ที่มุมเพื่อย่อ/ขยาย จากนั้นกด Apply Crop; ส่วน Resize มีปุ่ม Original, 50% และ Long Edge 1920 พร้อม Fit/Fill/Stretch, rotate, flip และ straighten
- **Remove BG** ใช้ Auto Remove Background เมื่อต้องการผลทันที หรือ Detect & Refine เพื่อเลือก Subject หลายรายการและแก้ mask ด้วยแปรง Keep/Remove จากนั้นปรับ Feather/Edge shift เลือก Transparent, White, Black หรือ Blur และกด Apply Removal
- **Upscale** เลือก 2× เพื่อลด memory/ขนาดผลลัพธ์ หรือ 4× เพื่อรายละเอียดสูงสุด แล้วกด Upscale
- **Erase** เลือก Add Mask แล้วระบายสีแดงทับวัตถุ ใช้ Subtract เพื่อลบส่วนเกินของ mask แล้วกด Remove Object
- **Generate / Fill Mask** เลือก Add Mask แล้วระบายบริเวณที่ต้องการ ใส่ prompt/seed และเลือก variant ก่อน Apply; ใช้ Subtract เพื่อลบ mask ส่วนเกิน และ Generate Again เพื่อสร้างชุดใหม่ด้วยค่าปัจจุบัน
- **Generate / Outpaint** เลือกทิศทางและเปอร์เซ็นต์ขยาย canvas จากนั้นให้ AI เติมบริเวณใหม่
- **OCR** เลือก Accurate สำหรับงานทั่วไปหรือ Fast สำหรับร่าง เลือก Auto Detect หรือภาษาที่ runtime รองรับ แล้วกด Recognize Text กรอบสีเหลืองแสดงตำแหน่งข้อความ ผลลัพธ์แก้ไขได้และคัดลอกหรือบันทึก `.txt` ได้ การรู้จำทำภายในเครื่องทั้งหมด

จาก Finder เลือกไฟล์ภาพแล้วเปิดเมนู Services เพื่อใช้ **Image Pro: Optimize Image** หรือ **Image Pro: Auto Remove Background** ผลลัพธ์จะถูกสร้างข้างไฟล์ต้นฉบับด้วยชื่อไม่ซ้ำ และ Finder จะเลือกไฟล์ใหม่ให้

## ตรวจและย้อนกลับ

ใช้ Before/After หรือ Split ด้านบนเพื่อตรวจผล ปุ่ม Undo/Redo ใช้กับ crop/resize/transform และ Undo Stroke ใช้กับ mask กด Revert เพื่อกลับต้นฉบับ กด Cancel ขณะงาน AI กำลังรันได้

ใช้ปุ่ม `−`, เปอร์เซ็นต์/Fit และ `+` ด้านล่างหรือถ่างสองนิ้วบน trackpad เพื่อซูม กดปุ่มรูปมือเพื่อ Pan แล้วลากภาพ หรือใช้ `⌘−`, `⌘+`, `⌘0` และ `⌘H` ตามลำดับ ขณะประมวลผลแอปจะบล็อกปุ่มอื่นชั่วคราวและให้กด Cancel ได้ เพื่อป้องกันงานชนกัน

## รูปแบบไฟล์

อ่านไฟล์ภาพที่ macOS/ImageIO รองรับ รวม JPEG, PNG, HEIC, TIFF และ WebP การ export รองรับ JPEG, PNG, HEIC, TIFF, WebP และ AVIF เมื่อ runtime รองรับ ควรใช้ PNG หรือ lossless WebP เมื่อต้องการเก็บความโปร่งใส

## Offline และพื้นที่จัดเก็บ

Processing path ไม่มี network API ตัวแอปประมาณ 6.6 MB และดาวน์โหลดโมเดลแยกเมื่อผู้ใช้เลือกเท่านั้น พื้นที่จริงขึ้นกับแพ็กที่ติดตั้ง Generative Fill ใช้หน่วยความจำมากที่สุดและโหลดโมเดลแบบ low-memory ทีละงาน การเช็กอัปเดตและ model catalog เป็น network boundary แยกจากงานประมวลผลรูป หลังติดตั้งโมเดลแล้วสามารถใช้งานโดยไม่ต่ออินเทอร์เน็ต

OCR ไม่สามารถรับประกันทุกภาษาและทุกลายมือได้ รายการภาษาอ่านจาก Vision ของ macOS เครื่องนั้นแบบ runtime หากผลลายมือสำคัญควรตรวจแก้ข้อความก่อนบันทึก ดูข้อสรุปการประเมิน model ที่ [OCR research](OCR_RESEARCH.md)

รายการ Recent มีปุ่ม Clear สำหรับล้างประวัติใน sidebar เท่านั้น ปุ่มนี้ไม่ลบไฟล์ภาพและไม่กระทบภาพที่เปิดอยู่
