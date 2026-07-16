# Technical research

ปรับปรุงล่าสุด: 2026-07-16  
ขอบเขต: เทคโนโลยีที่นำมาประกอบเป็นแอป macOS แบบ offline ได้จริง

## Executive recommendation

ใช้แอป native SwiftUI + AppKit และแยก processing เป็น provider protocol แต่ละฟีเจอร์ Core Image/ImageIO เป็นแกนภาพทั่วไป, Vision/Core ML สำหรับ AI เบา, Core ML Stable Diffusion สำหรับงาน generative และ C encoder แบบ static library สำหรับ format ที่ ImageIO ควบคุมไม่ได้ละเอียดพอ

ไม่แนะนำให้ฝัง Python runtime ใน MVP เพราะเพิ่มขนาด การเริ่มระบบ การจัด dependency และ failure modes มากเกินประโยชน์ แม้ IOPaint จะพิสูจน์ว่า workflow รวม LaMa, Stable Diffusion, background removal และ Real-ESRGAN ใช้ร่วมกันได้ก็ตาม

## Decision matrix

| Capability | ตัวเลือกที่แนะนำ | ทางเลือกสำรอง | ความพร้อม | เหตุผล |
|---|---|---|---|---|
| UI | SwiftUI + AppKit canvas bridge | AppKit ทั้งหมด | Adopt | native integration และสร้าง toolbar/sidebar เร็ว |
| Image graph | Core Image + Metal-backed `CIContext` | MetalPetal | Adopt | built-in, lazy recipe และ GPU accelerated |
| Decode/encode/metadata | ImageIO | libvips/ImageMagick | Adopt | color management และ metadata เป็น native |
| Background removal | Apple Vision foreground instance mask | BiRefNet Core ML | Adopt/Spike | Vision ไม่มี model package เพิ่ม; BiRefNet ใช้เป็น quality fallback |
| Upscale | Real-ESRGAN Core ML tiled | Real-ESRGAN ncnn-vulkan | Adopted | inference 2×/4× ผ่านบนเครื่องอ้างอิง |
| Object removal | LaMa Core ML | IOPaint local process | Adopted | 512 context crop/composite ผ่าน model จริง |
| Generative fill | Apple `ml-stable-diffusion` Swift package | IOPaint/Python sidecar | Adopted | masked img2img + outpaint ทำงาน offline |
| JPEG optimize | ImageIO ก่อน, MozJPEG เมื่อ quality/size ต้องดีกว่า | system `sips` | Adopt/Spike | MVP ง่าย; MozJPEG เพิ่ม compression efficiency |
| PNG optimize | ImageIO lossless ก่อน, pngquant สำหรับ lossy | oxipng | Later | pngquant ลดสีได้มากแต่เป็น lossy |
| WebP | bundled static libwebp 1.6.0 ผ่าน C bridge | ImageIO ถ้า runtime encode รองรับ | Adopt | รองรับ lossy/lossless/alpha/target-size และไม่ต้องมี runtime ภายนอก |
| AVIF | libavif | libheif | Later | dependency และเวลา encode สูงกว่า format หลัก |
| Queue | Swift actor + async task group | OperationQueue | Adopt | cancellation และ state isolation ชัดเจน |

## 1. Native image stack

### Core Image

Core Image รองรับ built-in/custom filters, compositing, geometry adjustment และทำงานผ่าน CPU/GPU context จึงเหมาะกับ operation graph, preview proxy และ final render โดยไม่สร้าง bitmap ใหม่ทุกขั้น [Apple Core Image](https://developer.apple.com/documentation/coreimage)

นำมาใช้กับ:

- crop, scale, rotate, flip
- color-space conversion
- alpha compositing และ mask preview
- feather/dilate/erode mask
- viewport rendering

ข้อควรระวัง:

- `CIImage` เป็น recipe ไม่ใช่ bitmap; ต้องกำหนด coordinate convention ให้เหมือนกันทั้งระบบ
- อย่าสร้าง `CIContext` ใหม่ทุก render
- Full-resolution render ต้องอยู่นอก main actor

### ImageIO

ImageIO อ่าน/เขียน format ส่วนใหญ่ มี color management และเข้าถึง EXIF/IPTC/XMP/GPS โดยตรง จึงใช้เป็น source of truth สำหรับ import/export และ metadata policy [Apple ImageIO](https://developer.apple.com/documentation/imageio)

สิ่งที่ยืนยันแล้วบนเครื่องพัฒนา:

- ImageIO decode WebP ได้ แต่ไม่มี WebP destination encoder
- แอปจึงใช้ libwebp 1.6.0 แบบ static สำหรับ encode และคง ImageIO สำหรับ decode

Spike ที่ยังต้องทำ:

- เรียก `CGImageDestinationCopyTypeIdentifiers()` บน macOS เป้าหมายจริงเพื่อยืนยัน encoder ของ HEIC/AVIF
- ทดสอบ HDR/gain map และ orientation round-trip
- ทดสอบ alpha behavior ของแต่ละ destination

## 2. Background removal

### Apple Vision — default

`GenerateForegroundInstanceMaskRequest` สร้าง instance mask ของวัตถุเด่นและรับ input เป็น URL, Data, CGImage, CVPixelBuffer หรือ CIImage ได้ จึงต่อกับ canvas pipeline ได้โดยไม่ต้องมี sidecar [Apple Vision request](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest)

ข้อดี:

- ไม่ต้อง bundle model
- ทำงาน offline และใช้ระบบ compute ของ Apple
- มี instance labels เหมาะกับ click-to-select

ข้อจำกัด:

- คุณภาพและ behavior เปลี่ยนตาม OS revision ได้
- ไม่รับประกันขอบผม/วัตถุซับซ้อนทุกภาพ จึงต้องมี manual refine

### BiRefNet — optional quality provider

BiRefNet ออกแบบมาสำหรับ high-resolution dichotomous segmentation และ source repository ใช้ MIT license [BiRefNet](https://github.com/ZhengPeng7/BiRefNet), [paper](https://arxiv.org/abs/2401.03407)

สถานะ: `Spike` ไม่ล็อกเป็น MVP จนกว่าจะผ่าน:

- conversion เป็น Core ML ด้วย input ขนาดที่เหมาะสม
- alpha edge comparison กับ Vision อย่างน้อย 30 ภาพ
- GPU/ANE correctness บน macOS เป้าหมาย

หมายเหตุ: มีรายงาน Core ML GPU NaN กับ fused QKV บาง configuration จึงต้องทดสอบบนเครื่องจริง ไม่ควรสมมติว่า conversion ใช้ได้ทุก compute unit [Apple Developer Forums](https://developer.apple.com/forums/thread/814557)

RMBG-2.0 ใช้ได้สำหรับงานส่วนตัวและมี alpha matte แบบ grayscale แต่ต้องกรอกขอ access และ weights ระบุ non-commercial; เนื่องจากโครงการนี้ใช้ส่วนตัวจึงเป็นตัวเลือกทดลอง ไม่ใช่ default dependency [RMBG-2.0 model card](https://huggingface.co/briaai/RMBG-2.0)

## 3. Upscale

### Real-ESRGAN Core ML — adopted

Real-ESRGAN รองรับ tile, alpha, grayscale และ 16-bit ใน implementation ต้นฉบับ และมี portable ncnn backend สำหรับ macOS [Real-ESRGAN](https://github.com/xinntao/real-esrgan)

implementation ใช้ RealESRGAN-x4plus FP16 แบบ 256→1024 จาก [RealESRGAN-CoreML](https://huggingface.co/VincentGOURBIN/RealESRGAN-CoreML) น้ำหนักประมาณ 33 MB และต้องใช้ macOS 15+

แผนทดลอง:

1. เริ่มจาก tile 256 px, overlap 24–32 px
2. รัน RGB tile; แยก alpha แล้ว upscale ด้วย high-quality scalar
3. ตัด overlap ด้วย weight ramp แล้ว composite
4. เปรียบเทียบกับ `realesrgan-ncnn-vulkan` เป็น reference
5. วัด cold load, warm inference, peak memory และ seam score

Fallback: bundle ncnn CLI แล้วเรียกผ่าน `Process` แต่จะทำให้ progress/cancel และ sandbox integration ซับซ้อนกว่า Core ML

## 4. Object removal

### Smart Erase: LaMa Core ML + edge-aware pipeline

LaMa ใช้ Fourier convolutions เพื่อรับ context กว้างและออกแบบมาสำหรับ large-mask inpainting [LaMa repository](https://github.com/advimman/lama), [paper](https://arxiv.org/abs/2109.07161)

implementation ใช้ LaMa Dilated Core ML แบบ 6-bit จาก [lama-dilated-coreml](https://huggingface.co/Dadm-n/lama-dilated-coreml) น้ำหนักประมาณ 38 MB รับ image/mask 512×512

Integration ที่แนะนำ:

1. หา bounding box ของ mask
2. ขยาย mask แบบ adaptive เพื่อคลุม fringe/เงา และขยาย context 2.75 เท่าของ bounding box
3. สร้าง square crop และ resize เป็น model input
4. รัน LaMa โดยใช้ mask ที่ขยายแล้ว
5. resize ผลกลับและ composite เฉพาะ expanded mask + adaptive feather band — implemented

วิธีนี้คงความละเอียดส่วนที่ไม่ถูกแก้และหลีกเลี่ยงการย่อทั้งภาพเป็น 512×512

IOPaint รวม LaMa, object replacement, background removal และ Real-ESRGAN ไว้แล้วและรองรับ Apple Silicon แต่ repository ถูก archive ในปี 2025 จึงใช้เป็น reference implementation/fallback เท่านั้น ไม่ใช้เป็น dependency หลัก [IOPaint](https://github.com/Sanster/IOPaint)

PowerPaint v2 แยก task prompt สำหรับ object removal, shape-guided generation และ outpaint ส่วน BrushNet เพิ่ม masked-image features เข้า diffusion model โดยตรง จึงเป็น candidate ที่คุณภาพเหนือ LaMa/SD1.5 สำหรับพื้นที่ซับซ้อน [PowerPaint](https://github.com/open-mmlab/PowerPaint), [BrushNet](https://github.com/TencentARC/BrushNet) อย่างไรก็ตาม release ปัจจุบันอาศัย PyTorch/Diffusers และ model weights หลาย GB ยังไม่มี Core ML package ที่ตรวจสอบคุณภาพแล้ว จึงยังไม่ฝัง Python sidecar เข้า native app ในรอบนี้

## 5. Generative fill

Apple มี `ml-stable-diffusion` เป็น Swift package สำหรับ deploy Stable Diffusion ผ่าน Core ML บน Apple Silicon โดย resource bundle เพิ่ม `VAEEncoder.mlmodelc` สำหรับ image-to-image/inpainting ได้ [Apple ml-stable-diffusion](https://github.com/apple/ml-stable-diffusion)

ข้อเท็จจริงที่มีผลต่อ UX:

- model resources มีขนาดหลาย GB
- peak memory อาจเกิน 2 GB ตาม model/compute unit
- compiled `.mlmodelc` ลดเวลา load ครั้งถัดไปเทียบกับ `.mlpackage`
- ต้องมี low-memory mode และ unload policy

ข้อเสนอและสถานะปัจจุบัน:

- bundled fallback ใช้ SD 1.5 img2img ที่ 512 px แต่ prefill พื้นที่ mask ด้วย context เบลอ ลด strength เริ่มต้นเป็น 0.58 และ composite ด้วย expanded feather mask เพื่อลดรอยต่อ/การคงวัตถุเดิม
- ถ้า resource folder มี `TextEncoder2.mlmodelc` แอปเลือก `StableDiffusionXLPipeline` และ context 1024 px อัตโนมัติ; official Apple conversion รองรับ SDXL และ SD3 แต่ compiled SDXL pack มีขนาดประมาณ 7 GB จึงเป็น optional pack [Apple ml-stable-diffusion](https://github.com/apple/ml-stable-diffusion), [Apple SDXL Core ML](https://huggingface.co/apple/coreml-stable-diffusion-xl-base)
- เก็บ generative provider หลัง protocol เพื่อเปลี่ยนเป็น model อื่นได้
- ไม่ load diffusion พร้อมกับ Real-ESRGAN/LaMa โดยไม่จำเป็น
- seed และ model manifest ต้องถูกบันทึกใน operation เพื่อ reproducibility

## 6. Image Optimize

### Native first

ใช้ ImageIO สำหรับ JPEG/PNG/HEIC, Core Image สำหรับ resize และ color conversion และวัด byte count จาก encoded `Data` จริง การหา target size ทำ binary search quality แล้วค่อยลด dimension

### Optional encoders

- MozJPEG ปรับ compression efficiency ของ JPEG และ compatible กับ decoder ทั่วไป [MozJPEG](https://github.com/mozilla/mozjpeg)
- `libwebp` รองรับ lossy/lossless และ alpha; implementation ปัจจุบันฝัง static library 1.6.0 แล้วเรียก C API โดยตรง ไม่สร้าง process และไม่ต้องติดตั้ง Homebrew ตอนใช้งาน [Google WebP encoding API](https://developers.google.com/speed/webp/docs/api)
- pngquant เป็น lossy PNG compressor ที่กำหนด minimum quality และไม่เขียนผลเมื่อคุณภาพต่ำกว่าเกณฑ์ได้ [pngquant](https://pngquant.org/)
- libavif เป็น C implementation สำหรับ encode/decode AVIF พร้อม alpha แต่เพิ่ม dependency และเวลา encode จึงเลื่อนไปหลัง MVP [libavif](https://github.com/AOMediaCodec/libavif)

ลำดับ adoption:

1. ImageIO JPEG/PNG/HEIC
2. libwebp สำหรับ WebP ที่ควบคุมได้แน่นอน — implemented
3. MozJPEG ถ้า benchmark แสดงว่าคุ้มกว่าความซับซ้อน
4. pngquant สำหรับ Small PNG preset
5. AVIF เมื่อ core workflow เสถียร

## 7. Compatibility contract

ทุก AI backend ต้อง implement contract เดียวกัน:

```swift
protocol ImageModelProvider: Sendable {
    var id: String { get }
    var manifest: ModelManifest { get }
    func prepare() async throws
    func unload() async
}

protocol ForegroundSegmenting: ImageModelProvider {
    func mask(for image: PixelImage) async throws -> MaskImage
}

protocol SuperResolving: ImageModelProvider {
    func upscale(_ image: PixelImage, scale: Int) async throws -> PixelImage
}

protocol Inpainting: ImageModelProvider {
    func fill(_ image: PixelImage, mask: MaskImage) async throws -> PixelImage
}
```

`PixelImage` และ `MaskImage` เป็น app-owned types เพื่อไม่ให้ UI ผูกกับ CVPixelBuffer, CGImage หรือ model-specific tensor

## 8. Required spikes before implementation lock

| ID | Spike | Pass condition |
|---|---|---|
| SP-01 | ImageIO format matrix | รู้ชัดว่า runtime encode/decode format ใดและ metadata ใด round-trip ได้ |
| SP-02 | Vision mask quality | 30-image set; มี baseline และ failure categories |
| SP-03 | Real-ESRGAN Core ML | 10 images, ไม่มี seam, memory อยู่ในงบ, output เทียบ reference ได้ |
| SP-04 | LaMa Core ML | crop/composite ทำงานกับ mask 5 รูปทรงและไม่เปลี่ยนนอก mask |
| SP-05 | Optimize target bytes | ผลไม่เกิน target >2% และไม่ infinite loop |
| SP-06 | Stable Diffusion memory | generate/inpaint สำเร็จบนเครื่องเป้าหมายโดย UI ไม่ถูก kill |

## 9. Final stack recommendation

```text
macOS 14+, Apple Silicon
SwiftUI + AppKit
Core Image + ImageIO + Vision
Core ML providers
  ├─ Apple Vision foreground mask
  ├─ Real-ESRGAN 4x tiled
  ├─ Smart Erase: LaMa 512 context crop + adaptive mask/edge blend
  └─ Stable Diffusion 1.5 fallback / optional SDXL Core ML 1024
Format encoders
  ├─ ImageIO: JPEG, PNG, HEIC
  ├─ libwebp: WebP
  ├─ MozJPEG/pngquant: optional optimize modes
  └─ libavif: later
Swift actor-based Job Queue
```
