# Offline OCR research and implementation decision

วันที่ตรวจสอบ: 2026-07-15  
เป้าหมาย: OCR จากรูปแบบ offline บน Apple Silicon โดยรองรับหลายภาษาและลายมือเท่าที่ทำได้จริง

## ข้อสรุป

ไม่มีโมเดลเดียวที่ยืนยันได้ว่าอ่าน “ทุกภาษา + ทุกลายมือ” ได้แม่นในทุกสภาพภาพ การเลือกใช้งานจึงต้องวัดกับภาพจริงตามภาษา ชนิดเอกสาร ฟอนต์ และลายมือของผู้ใช้

Image Pro ใช้ **Apple Vision `VNRecognizeTextRequest`** เป็น provider เริ่มต้น เพราะติดมากับ macOS, ทำงานบนเครื่อง, ไม่ต้องเพิ่ม model/runtime ขนาดใหญ่ และรายงานภาษาที่รองรับจาก runtime จริง แอปมี Fast/Accurate, Auto Detect, ระบุภาษา, language correction, confidence, bounding boxes, แก้ข้อความ, Copy และ Save TXT

บนเครื่องอ้างอิง macOS 26.5.2 Vision รายงาน 30 locale รวมไทย อังกฤษ จีน ญี่ปุ่น เกาหลี อาหรับ รัสเซีย และภาษายุโรปหลายภาษา รายการนี้ไม่ hard-code และอาจต่างกันตาม OS

## ตัวเลือกที่ประเมิน

| ทางเลือก | ภาษา/ลายมือ | Offline macOS | ต้นทุนรวม | คำตัดสิน |
|---|---|---|---|---|
| Apple Vision | ภาษาตาม runtime; revision ใหม่ปรับ text/handwriting แต่ไม่รับรองว่าครบทุกลายมือ | Native และ on-device | ต่ำ | ใช้เป็น default |
| PaddleOCR PP-OCRv5 | เอกสารระบุ 106 ภาษาโดยแยก recognition model ตาม script/language | ทำได้ แต่ต้อง bundle runtime หรือทำ native conversion | กลาง–สูง | Provider เสริมหลัง benchmark ภาพจริง |
| PaddleOCR PP-OCRv6 | unified 50 ภาษาในรุ่นปัจจุบันของโครงการ | deployment บน macOS ยังไม่เรียบเท่า Vision | กลาง–สูง | ติดตาม ไม่แทน default ตอนนี้ |
| Microsoft TrOCR | checkpoint ลายมืออ้างอิง IAM และเอกสารอังกฤษเป็นหลัก | ต้องแปลง/ฝัง runtime เพิ่ม | สูง | ไม่ใช่ universal multilingual solution |
| PencilKit `PKStrokeRecognizer` | 29 ภาษาและ on-device | macOS 27+; ต้องมีข้อมูล stroke ไม่ใช่ bitmap OCR ทั่วไป | ต่ำเมื่อ input เป็น strokes | เหมาะกับ canvas เขียนในอนาคต |

## เหตุผลที่ยังไม่ bundle PaddleOCR

1. การเพิ่ม runtime/model หลายชุดเพิ่มขนาดแอป การเริ่มช้า และงานดูแล packaging
2. จำนวนภาษาที่ระบุไม่เท่ากับความแม่นกับภาพจริง โดยเฉพาะลายมือ คุณภาพกล้อง ตาราง ตัวหนังสือโค้ง และข้อความหลาย script
3. Vision ครอบคลุมภาษาไทยบนเครื่องเป้าหมายแล้ว จึงควรเก็บ failure set ก่อนเพิ่ม engine ที่สอง
4. Core มี provider boundary ทำให้เพิ่ม PaddleOCR ภายหลังได้โดยไม่ต้องเปลี่ยน UI/workflow

## เกณฑ์ตัดสินใจเพิ่ม engine ที่สอง

เก็บชุดทดสอบอย่างน้อยภาษา/ชนิดละ 20 ภาพ พร้อม ground truth แล้ววัด Character Error Rate (CER), Word Error Rate (WER), เวลารัน และ peak memory เพิ่ม PaddleOCR เมื่ออย่างน้อยหนึ่งกลุ่มสำคัญมี CER ดีขึ้นอย่างมีนัยสำคัญและผ่านข้อจำกัดขนาดแอป/เวลาเริ่มต้น

กลุ่มที่ควรทดสอบก่อน: ไทยพิมพ์, ไทยลายมือ, อังกฤษพิมพ์, อังกฤษลายมือ, เอกสารไทย+อังกฤษ, ใบเสร็จ, ป้ายเอียง/แสงน้อย และข้อความบนพื้นหลังซับซ้อน

## แหล่งข้อมูลหลัก

- Apple Vision: <https://developer.apple.com/documentation/vision/vnrecognizetextrequest>
- Apple PencilKit handwriting, WWDC26: <https://developer.apple.com/videos/play/wwdc2026/203/>
- PaddleOCR PP-OCRv5 multilingual: <https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/algorithm/PP-OCRv5/PP-OCRv5_multi_languages.en.md>
- PaddleOCR project: <https://github.com/PaddlePaddle/PaddleOCR>
- Microsoft TrOCR: <https://github.com/microsoft/unilm/blob/master/trocr/README.md>

