# Bundled model notices

## RealESRGAN-x4plus

- Source: VincentGOURBIN/RealESRGAN-CoreML; converted from xinntao/Real-ESRGAN
- License: BSD-3-Clause
- Runtime requirement: macOS 15 or later
- Input/output: RGB Float16 256×256 → 1024×1024

## LaMa-Dilated

- Source: Dadm-n/lama-dilated-coreml; derived from anyisalin/big-lama and advimman/lama
- License: Apache-2.0
- Input/output: RGB image + binary mask Float32 512×512
- Compression: 6-bit palettized weights

## Stable Diffusion 1.5 Core ML

- Runtime: Apple `ml-stable-diffusion` Swift package 1.1.1
- Resources: Apple Core ML Stable Diffusion v1.5 compiled model bundle
- Model license: CreativeML Open RAIL-M
- Components: TextEncoder, UNet, VAEEncoder, VAEDecoder and tokenizer data
- Use: local image-to-image masked fill and outpainting; low-memory resource loading is enabled

Model weights are executed locally through Core ML. No image data is sent over the network.
