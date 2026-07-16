# Model evolution research — 2026-07-16

## Decision

Image Pro ใช้ lightweight app + external model packs แทนการฝัง weights ใน `.app` โมเดลที่ใช้ engine ABI เดิมอัปเดตผ่าน catalog ได้โดยไม่อัปเดตแอป ส่วน model family ที่ต้องใช้ runtime ใหม่ต้องเพิ่ม provider ผ่าน app OTA ก่อน

## Recommended stack

| Capability | Fast/default | Quality/optional | Runtime direction |
|---|---|---|---|
| Object mask | Apple Vision | SAM 2.1 Tiny/Base+ | Vision + Core ML/ONNX spike |
| Object erase | LaMa | FLUX.1 Fill | Core ML + MLX model host |
| Generate/edit | SD Core ML compatibility | FLUX.2 Klein 4B int4 | Native Swift MLX preferred |
| OCR scene/printed | Vision | PP-OCRv5 Thai/Latin, PP-OCRv6 | converted native provider |
| OCR document | Vision | PaddleOCR-VL 1.6 0.9B | MLX-VLM isolated host |
| OCR handwriting | Vision | Chandra 2 optional | benchmark-gated MLX pack |

## Why routing is required

- ไม่มี OCR model เดียวรับประกันทุกภาษาและทุกลายมือพร้อม bounding boxes ที่แม่น
- LaMa เร็วและเหมาะกับพื้นที่เล็ก แต่ diffusion/fill model ทำ texture ซับซ้อนได้ดีกว่า
- โมเดล quality ใช้ RAM/เวลาสูง จึงไม่ควรถูกโหลดทุกงาน
- ผลลบวัตถุต้อง composite เฉพาะ mask และตรวจว่าพิกเซลนอก protected region ไม่เปลี่ยน

## Runtime boundary

Core ML provider ยังอยู่ใน process หลัก ส่วน MLX-VLM/โมเดล image transformer ควรรันใน helper process ที่สื่อสารผ่าน local JSON IPC เท่านั้น เมื่อจบงานให้ terminate helper เพื่อคืน unified memory อย่างแน่นอน ห้ามส่งรูปผ่าน HTTP หรือ external API

## Sources

- SAM 2.1: <https://github.com/facebookresearch/sam2>
- FLUX.1 Fill: <https://github.com/black-forest-labs/flux/blob/main/docs/fill.md>
- FLUX.2 Klein: <https://github.com/black-forest-labs/flux2>
- Native Swift FLUX.2 MLX prototype: <https://github.com/VincentGourbin/flux-2-swift-mlx>
- PP-OCRv5 multilingual: <https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/algorithm/PP-OCRv5/PP-OCRv5_multi_languages.en.md>
- PaddleOCR-VL 1.6: <https://huggingface.co/PaddlePaddle/PaddleOCR-VL-1.6>
- MLX-VLM: <https://github.com/Blaizzy/mlx-vlm>
- Chandra 2: <https://github.com/datalab-to/chandra>
