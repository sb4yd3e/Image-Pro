# Reference benchmark

วันที่: 2026-07-15  
เครื่อง: MacBook Pro M1 Pro 10-core, RAM 32 GB  
ระบบ: macOS 26.5.2, arm64  
โหมด: Debug XCTest, warm local model resources

| Provider | Input | Output | เวลา test |
|---|---:|---:|---:|
| LaMa Core ML | 256×192 + mask | 256×192 | 4.81 s |
| Real-ESRGAN 4× | 48×32 | 192×128 | 2.27 s |
| Real-ESRGAN 2× | 32×24 | 64×48 | 2.31 s |
| Stable Diffusion fill | 96×72, 2 steps | 96×72 | 5.77 s |

ผลนี้ยืนยัน model load/inference/composite และมิติ output ไม่ใช่ quality benchmark เวลารูปจริงขึ้นกับจำนวน tile, diffusion steps และ cold/warm model state ตัว audit ชุดภาพจริงล่าสุดตรวจ 28 ภาพผ่าน 28/28 (`docs/reports/image-audit-2026-07-15.json`)

Full XCTest ล่าสุด 59/59 ผ่านใน 24.8 วินาที รวม OCR text rendering, Vision foreground, Core ML providers, Batch Auto BG + Resize/preserved folders, WebP และ golden-image comparator

CLI มี benchmark harness สำหรับภาพจริงซึ่งรายงานเวลา inspect/preview/full decode/optimize พร้อม current และ peak resident memory:

```bash
swift run imagepro-probe --benchmark-image "/path/to/24mp.jpg" --output benchmark.json
```

Golden-image harness เปรียบเทียบ RGBA แบบ pixel-level และรายงาน maximum/mean channel difference, changed-pixel ratio และ pass/fail ตาม tolerance:

```bash
swift run imagepro-probe --compare-images actual.png baseline.png --output comparison.json
```

## 24 MP pipeline smoke

ภาพทดสอบ 6,000×4,000 ถูกสร้างจาก UI mockup เพื่อวัดเส้นทางและ memory guard (ไม่ใช้ตัดสินคุณภาพ): inspect 7.7 ms, bounded preview 116.5 ms, full decode 77.4 ms, balanced JPEG optimize 190.3 ms, current RSS 222 MB และ peak RSS 398 MB ดู raw report ที่ `docs/reports/benchmark-24mp-2026-07-15.json`
