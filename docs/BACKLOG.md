# Backlog

Priority: P0 = ต้องมี/ลดความเสี่ยง, P1 = สำคัญ, P2 = ภายหลัง  
Status: Todo / Doing / Blocked / Done

## Tracking table

| ID | P | Status | งาน | Acceptance / output | Depends on |
|---|---:|---|---|---|---|
| SET-001 | P0 | Done | สร้าง macOS app + Swift package | Build/run ได้บน macOS เป้าหมาย | — |
| SET-002 | P0 | Done | เพิ่ม test targets และ fixtures folder | Unit test ตัวอย่างผ่าน | SET-001 |
| SET-003 | P0 | Done | กำหนด app folders และ model manifest schema | Round-trip Codable test ผ่าน | SET-001 |
| SP-001 | P0 | Doing | ImageIO capability probe | สร้าง format/metadata report | SET-001 |
| SP-002 | P0 | Doing | Vision foreground sample | Export grayscale mask ได้ | SET-001 |
| SP-003 | P0 | Done | Real-ESRGAN Core ML inference spike | 2×/4× dimension/time evidence; quality set ทำต่อใน QA | SET-001 |
| SP-004 | P0 | Done | LaMa Core ML inference spike | Context crop/composite proof ผ่าน model จริง | SET-001 |
| SP-005 | P0 | Done | Target-size prototype | อยู่ใต้ target ภายใน 2% | SET-001 |
| DOC-001 | P0 | Done | Product/technical/roadmap docs | เอกสารใน `docs/` | — |
| UI-001 | P0 | Done | App shell: sidebar/canvas/inspector | Resize window และ session restore ได้ | SET-001 |
| UI-002 | P0 | Done | Drag/drop + open panel | เปิดภาพที่รองรับและแสดง error ได้ | UI-001 |
| UI-003 | P1 | Done | Before/After controls | toggle + draggable split ใช้ได้ | UI-001 |
| UI-004 | P1 | Done | UI polish + runtime TH/EN | panel spacing ไม่เบียด, ไทย/อังกฤษเปลี่ยนทันทีและจำค่า | UI-001 |
| UI-005 | P0 | Done | Large-image/pan/zoom/split hardening | bounded async preview, pinch zoom, fixed divider, full-row sidebar hit area, hidden scroll indicators | IMG-003 |
| UI-006 | P0 | Done | Processing interaction lock | overlay blocks conflicting controls and exposes Cancel | BAT-002 |
| IMG-001 | P0 | Doing | Image source abstraction | Orientation/profile tests ผ่าน | SP-001 |
| IMG-002 | P0 | Done | Reusable Core Image context | provider/renderers ใช้ shared context | IMG-001 |
| IMG-003 | P0 | Done | Proxy/viewport renderer | bounded preview proxy + pan/zoom; 24 MP regression ผ่าน | IMG-002 |
| IMG-004 | P0 | Done | Operation graph + undo/redo | 50 operations round-trip | IMG-001 |
| EDIT-001 | P0 | Done | Crop interaction | preset/free crop ผ่าน tests | IMG-004 |
| EDIT-002 | P0 | Done | Resize engine | exact output dimensions | IMG-004 |
| EDIT-003 | P1 | Done | Rotate/flip/straighten | operation graph และ UI เชื่อมครบ | IMG-004 |
| EDIT-004 | P1 | Done | Canvas resize/Fit/Fill | resize modes + outpaint expansion | IMG-004 |
| OPT-001 | P0 | Done | Optimize parameter model/presets | Codable + default tests | SP-005 |
| OPT-002 | P0 | Done | JPEG/PNG/HEIC encoders | actual byte reporting | SP-001 |
| OPT-003 | P0 | Done | Metadata policy | GPS/EXIF removal verified by reread | OPT-002 |
| OPT-004 | P0 | Done | Target-size solver | bound/termination tests | OPT-002 |
| OPT-005 | P1 | Done | Auto format classifier | alpha/photo/flat graphic fixtures pass | OPT-002 |
| OPT-006 | P1 | Done | libwebp adapter | lossy/lossless/alpha tests | SP-001 |
| OPT-010 | P0 | Done | Optimize preview-before-save | conversion result/bytes visible before Save panel | OPT-004 |
| OPT-007 | P2 | Todo | MozJPEG comparison | adopt/reject decision recorded | OPT-002 |
| OPT-008 | P2 | Todo | pngquant adapter | quality floor behavior tested | OPT-002 |
| OPT-009 | P2 | Todo | AVIF adapter | encode/decode/alpha test | OPT-006 |
| EXP-001 | P0 | Done | Atomic export | no partial output on cancel/crash | IMG-001 |
| EXP-002 | P1 | Done | Naming/collision policy | replace/skip/unique tests pass | EXP-001 |
| BAT-001 | P0 | Done | Persistent queue actor | relaunch recovery test pass | EXP-001 |
| BAT-002 | P0 | Done | Progress/cancel/retry core | UI cancel + queue retry state | BAT-001 |
| BAT-003 | P1 | Done | Folder import/output mapping | recursive import + preserve structure test ผ่าน | BAT-001 |
| BG-001 | P0 | Done | Vision provider | mask output contract | SP-002 |
| BG-002 | P0 | Done | Mask overlay/instance picker | overlay + select multiple subjects | BG-001 |
| BG-003 | P0 | Done | Keep/Remove brush | normalized mask strokes + undo/clear | BG-002 |
| BG-004 | P1 | Done | Feather/shift controls | morphology + blur mask pipeline | BG-003 |
| BG-005 | P1 | Done | Background composite presets | transparent/white/black/blur | BG-003 |
| BG-006 | P2 | Todo | BiRefNet provider spike | compare against Vision | BG-001 |
| SR-001 | P0 | Done | Real-ESRGAN provider | model load + tile inference | SP-003 |
| SR-002 | P0 | Done | Overlap tile assembly | central-crop overlap removes hard tile borders | SR-001 |
| SR-003 | P1 | Todo | Viewport preview | selected area before full run | SR-001 |
| SR-004 | P1 | Done | 2×/4× output scale | model tests verify dimensions | SR-002 |
| SR-005 | P1 | Todo | Anime model | model switch/unload works | SR-001 |
| MSK-001 | P0 | Done | Mask document + strokes | normalized raster/paint/refine/undo tests | IMG-004 |
| MSK-002 | P0 | Done | Brush UI | size/mode/undo/clear | MSK-001 |
| ERA-001 | P0 | Done | LaMa provider | image+mask inference ผ่าน | SP-004 |
| ERA-002 | P0 | Done | Context crop planner | edge/center mask planning | ERA-001 |
| ERA-003 | P0 | Done | Composite/apply | original dimensions + mask-only blend | ERA-002 |
| ERA-004 | P1 | Done | Generate Again variants | rerun current fill/outpaint configuration | ERA-003 |
| MOD-001 | P1 | Done | External model inventory/validation | manifests + SHA + separate ZIP packs | SET-003 |
| MOD-002 | P1 | Done | Model lifecycle | Stable Diffusion reduce-memory + unload after run | MOD-001 |
| MOD-003 | P0 | Done | Model Manager | import/download/activate/remove/rollback + compatibility validation | MOD-001 |
| MOD-004 | P1 | Todo | Signed remote catalog | publish packs and pin catalog signing key | MOD-003 |
| MOD-005 | P1 | Todo | MLX model host | isolated process, JSON IPC, unload by process exit | MOD-003 |
| GEN-001 | P1 | Done | Stable Diffusion provider | local Core ML inference smoke test | MOD-001 |
| GEN-002 | P1 | Done | Masked fill pipeline | image+mask+prompt result | GEN-001 |
| GEN-003 | P1 | Done | Prompt/seed/variants UI | filmstrip + apply/discard | GEN-002 |
| GEN-004 | P1 | Done | Outpainting workflow | direction/fraction canvas + mask | GEN-002 |
| GEN-005 | P1 | Done | Low-memory mode | reduceMemory/unload; 8GB hardware test ยังเป็น QA | MOD-002 |
| GEN-006 | P0 | Done | Generation coherence hardening | mask prefill, lower strength, negative prompt, optional SDXL auto-detection | GEN-002 |
| ERA-005 | P0 | Done | Smart Erase edge hardening | adaptive mask expansion/context/feather composite | ERA-003 |
| OCR-001 | P0 | Done | Vision OCR provider | runtime languages + fast/accurate + recognition test | SET-001 |
| OCR-002 | P0 | Done | OCR workflow UI | boxes + editable text + copy/TXT export | OCR-001 |
| OCR-003 | P1 | Todo | Multilingual/handwriting benchmark | CER/WER dataset ไทย/อังกฤษพิมพ์และลายมือ | OCR-001 |
| OCR-004 | P2 | Todo | PaddleOCR provider spike | เพิ่มเมื่อ OCR-003 ยืนยัน gap ของ Vision | OCR-003 |
| OCR-005 | P1 | Todo | PaddleOCR-VL MLX provider | document/handwriting fallback + no-image-data network test | MOD-005 |
| ERA-006 | P1 | Todo | SAM 2.1 + quality inpaint | click/box mask and FLUX Fill comparison | MOD-005 |
| GEN-007 | P1 | Todo | FLUX.2 Klein 4B provider | int4 MLX generation/edit on M1 Pro 32 GB | MOD-005 |
| QA-001 | P0 | Done | Golden image harness | pixel/tolerance JSON comparator + tests | SET-002 |
| QA-002 | P0 | Done | Benchmark harness | time + peak memory JSON report | SET-002 |
| QA-003 | P0 | Done | Offline architecture test | image-processing core ไม่มี network client API; updater แยก app boundary | SET-001 |
| QA-004 | P1 | Doing | Accessibility audit | keyboard shortcuts/labels เพิ่มแล้ว; manual VoiceOver checklist เหลือ | UI-001 |
| REL-001 | P0 | Done | GitHub Release OTA | stable release check, SHA-256/bundle/version verification, safe replacement | SET-001 |
| DOC-002 | P0 | Done | README + MIT license + App Icon | release/build/update docs and blueprint `.icns` included | DOC-001 |

## Ready rule

Task เริ่ม `Doing` ได้เมื่อ dependency เป็น Done, มี fixture/input ที่ใช้ทดสอบ และ acceptance criterion ไม่คลุมเครือ

## Done rule

- Code และ test อยู่ใน repository
- Acceptance ผ่าน
- ไม่มี warning/error ใหม่ที่เกี่ยวข้อง
- STATUS และ decision log ถูกอัปเดตเมื่อมีผลต่อแผน
