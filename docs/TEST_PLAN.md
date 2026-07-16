# Test plan

## 1. Test levels

### Unit

- dimension/aspect math
- crop coordinate conversion
- target-size search termination
- metadata policy
- naming/collision rules
- model manifest validation
- operation serialization/migration

### Golden image

- orientation และ color profile
- alpha premultiplication
- resize kernels
- tile seam
- mask feather/contract/expand
- outside-mask invariance หลัง inpaint composite

### Integration

- import → operations → export
- model load → infer → unload
- queue cancellation ระหว่าง encode/write
- app relaunch และ project recovery
- model missing/corrupt/incompatible

### Manual UX

- drag/drop หลายชนิดไฟล์
- keyboard-only workflow
- VoiceOver labels
- Before/After และ zoom/pan
- low-memory warning และ recovery

## 2. Fixture set

สร้าง `Tests/Fixtures` โดยไม่ commit รูปส่วนตัว ประกอบด้วย:

- JPEG: portrait, landscape, high noise, compressed artifact
- PNG: alpha, flat icon, screenshot/text, 16-bit
- HEIC: Display P3, orientation variants, GPS metadata
- WebP: lossy/lossless/alpha
- Large: 24 MP และ panorama
- Masks: center, edge, corner, thin line, large irregular region
- Upscale seam patterns: gradient, checker, diagonal, repeating texture

## 3. Quality gates

| Area | Gate |
|---|---|
| Export dimension | ตรง 100% |
| Target bytes | ไม่เกินเป้าหมายมากกว่า 2% |
| Metadata removal | ไม่มี key ที่ policy สั่งลบหลังอ่านกลับ |
| Alpha | ไม่มี dark halo ใน golden fixtures |
| Inpaint composite | นอก feather band ต่างไม่เกิน tolerance |
| Tile upscale | ไม่มี visible seam และ numeric seam metric ต่ำกว่า baseline |
| Offline | ไม่มี outbound connection ระหว่าง test session |
| Reliability | partial file ไม่ปรากฏที่ final path |

## 4. Performance budget

ตัวเลขเริ่มต้น ต้องปรับหลัง Phase 0 benchmark บนเครื่องจริง

- UI input response: <100 ms
- Open 24 MP: window/proxy usable <1 s
- Crop/resize preview: <150 ms หลังหยุดลาก
- Background mask: เป้าหมาย <3 s ต่อภาพทั่วไป
- Optimize JPEG 24 MP: เป้าหมาย <3 s
- Peak memory non-generative: เป้าหมาย <2 GB
- AI provider concurrency: 1 heavy job โดย default
- Batch encode concurrency: min(4, performance cores) แต่ลดเมื่อ memory pressure

## 5. Hardware matrix

ขั้นต่ำที่ต้องกรอกหลังทราบเครื่องใช้งานจริง:

| Machine | RAM | OS | Role | Status |
|---|---:|---|---|---|
| MacBook Pro M1 Pro 10-core | 32 GB | macOS 26.5.2 | Development/reference | 53 tests + 28-image audit + release/UI smoke passed |
| Lowest-memory target | 8 GB หรือเครื่องที่มี | TBD | Low-memory validation | Pending |

## 6. Failure injection

- disk full ระหว่าง export
- output permission ถูกถอน
- model file ถูกตัด/แก้ hash
- cancel ระหว่าง inference และ write
- memory pressure notification
- source file ถูกย้ายหลังเปิด project
- app terminate ระหว่าง queue

## 7. Benchmark report template

```text
Date / commit:
Machine / OS:
Model + SHA:
Input dimensions:
Cold load:
Warm inference:
Peak resident memory:
Output dimensions/bytes:
Visual notes:
Pass/Fail:
```
