# UI specification

## Design direction

Native macOS utility ที่ดูสงบและตรงไปตรงมา ใช้ visual hierarchy แบบ Finder/Preview มากกว่า dashboard แนวเว็บ

- Window เริ่มต้น 1240×780 และขั้นต่ำ 1180×720 เพื่อให้ภาษาไทยไม่เบียด toolbar/inspector
- รองรับ Light/Dark mode แต่ mockup แรกใช้ dark neutral
- Accent: indigo/violet ใช้เฉพาะ selection และ primary action
- Canvas background: charcoal checkerboard เมื่อมี alpha
- Corner radius 8–12 pt
- ใช้ SF Symbols ใน implementation จริง
- Toolbar สูง 60 pt, status bar สูง 36 pt, ช่องว่างระหว่างสาม panel 10 pt
- Sidebar กว้าง 220 pt และ inspector กว้าง 330 pt; content padding 14–20 pt ตามความหนาแน่นของฟอร์ม
- Sidebar, canvas และ inspector เป็นแผงมุมโค้งแยกจากกัน เพื่อลดความรู้สึกชิดขอบโดยไม่เสียพื้นที่ใช้งาน
- รองรับภาษาไทย/อังกฤษแบบ runtime จากปุ่ม EN/TH และหน้าต่าง Settings (`⌘,`)

## Primary editor layout

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Image Pro   Open   Undo Redo       Before | After      Export       │
├──────────────┬───────────────────────────────────────┬───────────────┤
│ Library      │                                       │ Optimize      │
│              │               Canvas                  │               │
│ Recent       │                                       │ Balanced      │
│ Batch Queue  │         image + comparison lens       │ WebP / Auto   │
│              │                                       │ Quality 82    │
│ Tools        │                                       │ Remove GPS ✓  │
│ Optimize     │                                       │               │
│ Remove BG    │                                       │ 8.4 → 1.2 MB  │
│ Crop/Resize  │                                       │               │
│ Upscale      │                                       │ [Export]      │
│ Erase        │                                       │               │
│ Generate     │                                       │               │
├──────────────┴───────────────────────────────────────┴───────────────┤
│ Ready · 4032×3024 · Display P3                    Zoom 74%          │
└──────────────────────────────────────────────────────────────────────┘
```

## Interaction rules

- Tool selection เปลี่ยน Inspector แต่ไม่เปิด modal
- `Return` ใช้ Apply, `Escape` ใช้ Cancel draft
- Space + drag = pan, `⌘+`/`⌘-` = zoom
- Hold `\` แสดง original ชั่วคราว
- Compare มี Split, Hold Original และ side-by-side
- ค่า Recommended แสดงก่อน Advanced
- AI tools มี Generate/Preview ก่อน Apply เสมอ

## Optimize inspector

- Preset segmented/menu
- Format: Auto เป็น default
- Estimated output card แสดงขนาดเดิม/ใหม่/เปอร์เซ็นต์
- Target Size เปิด field และ priority menu เฉพาะเมื่อเลือก preset
- Metadata แสดง `Remove private metadata` เป็น checkbox เดียว; รายละเอียดอยู่ Advanced
- Export เป็น primary button ติดล่าง inspector

## Background removal inspector

- `Detect Subject` primary action
- Instance chips เมื่อพบหลายวัตถุ
- View: Result / Mask / Overlay
- Refine brush: Keep / Remove
- Edge: Smooth, Feather, Shift Edge
- Background: Transparent / Color / Image / Blur

## Erase and generative fill

- Tool rail แสดง brush size popover
- Quick Remove ไม่แสดง prompt
- Generative Fill แสดง prompt + Variants + Seed ใน Advanced
- แสดง result variants เป็น filmstrip ด้านล่าง canvas
- Apply ถูก disable จนเลือก variant

## Empty and error states

- Empty canvas: drop zone + 4 Quick Action cards
- Missing model: อธิบายชื่อ model และปุ่ม Import Model
- Low memory: ปุ่ม Retry Low Memory และลด preview size
- Unsupported output: แนะนำ format ที่รักษา alpha/color ได้

## Mockup asset

ภาพ mockup ที่สร้างจาก specification นี้ควรบันทึกเป็น `design/image-pro-editor-mockup.png` และใช้เป็น visual reference ไม่ใช่ pixel-perfect implementation contract
