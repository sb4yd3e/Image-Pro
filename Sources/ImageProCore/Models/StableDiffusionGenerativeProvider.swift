import CoreGraphics
import CoreImage
import CoreML
import Foundation
import StableDiffusion

public struct GenerativeFillConfiguration: Sendable {
    public var prompt: String
    public var negativePrompt: String
    public var seed: UInt32
    public var strength: Float
    public var stepCount: Int
    public var variantCount: Int

    public init(
        prompt: String,
        negativePrompt: String = "",
        seed: UInt32 = 1,
        strength: Float = 0.58,
        stepCount: Int = 20,
        variantCount: Int = 1
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.seed = seed
        self.strength = min(max(strength, 0.01), 0.99)
        self.stepCount = min(max(stepCount, 2), 50)
        self.variantCount = min(max(variantCount, 1), 4)
    }
}

@available(macOS 14.0, *)
public final class StableDiffusionGenerativeProvider {
    private let resourcesURL: URL
    private let renderer: CoreImageRenderer

    public init(resourcesURL: URL, renderer: CoreImageRenderer = .shared) {
        self.resourcesURL = resourcesURL
        self.renderer = renderer
    }

    public func fill(
        image: CGImage,
        mask: CGImage,
        configuration: GenerativeFillConfiguration,
        progress: (Double) -> Bool = { _ in true }
    ) throws -> [CGImage] {
        let isXL = FileManager.default.fileExists(
            atPath: resourcesURL.appendingPathComponent("TextEncoder2.mlmodelc").path
        )
        let inputSize = isXL ? 1_024 : 512
        let imageSize = PixelSize(width: image.width, height: image.height)
        let rect = try ContextCropPlanner.contextRect(mask: mask, imageSize: imageSize, expansion: 2.2)
        guard
            let imageCrop = image.cropping(to: rect),
            let maskCrop = mask.cropping(to: rect)
        else {
            throw ImageProcessingError.renderFailed
        }
        let startingImage = try preparedStartingImage(
            image: imageCrop,
            mask: maskCrop,
            inputSize: inputSize
        )

        let modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = .cpuAndGPU
        let pipeline: StableDiffusionPipelineProtocol
        if isXL {
            pipeline = try StableDiffusionXLPipeline(
                resourcesAt: resourcesURL,
                configuration: modelConfiguration,
                reduceMemory: true
            )
        } else {
            pipeline = try StableDiffusionPipeline(
                resourcesAt: resourcesURL,
                controlNet: [],
                configuration: modelConfiguration,
                disableSafety: true,
                reduceMemory: true
            )
        }
        try pipeline.loadResources()
        defer { pipeline.unloadResources() }

        let qualityPrompt = configuration.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            + ", coherent detail, matching surrounding lighting, perspective, color and texture"
        let defaultNegative = "distorted, deformed, duplicate, blurry, low quality, text, watermark, hard seam, mismatched lighting"
        var pipelineConfiguration = StableDiffusionPipeline.Configuration(prompt: qualityPrompt)
        pipelineConfiguration.negativePrompt = configuration.negativePrompt.isEmpty
            ? defaultNegative
            : configuration.negativePrompt + ", " + defaultNegative
        pipelineConfiguration.startingImage = startingImage
        pipelineConfiguration.strength = configuration.strength
        pipelineConfiguration.stepCount = configuration.stepCount
        pipelineConfiguration.seed = configuration.seed
        pipelineConfiguration.imageCount = configuration.variantCount
        pipelineConfiguration.guidanceScale = isXL ? 5.5 : 6.5
        pipelineConfiguration.disableSafety = true
        pipelineConfiguration.schedulerType = .dpmSolverMultistepScheduler

        let generated = try pipeline.generateImages(configuration: pipelineConfiguration) { state in
            progress(Double(state.step) / Double(max(1, state.stepCount)))
        }.compactMap { $0 }

        return try generated.map {
            try composite(
                generated: $0,
                original: image,
                originalCrop: imageCrop,
                maskCrop: maskCrop,
                rect: rect
            )
        }
    }

    private func preparedStartingImage(image: CGImage, mask: CGImage, inputSize: Int) throws -> CGImage {
        let original = CIImage(cgImage: image)
        let extent = original.extent
        let blurred = original
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: max(12, min(extent.width, extent.height) * 0.045)
            ])
            .cropped(to: extent)
        let softMask = CIImage(cgImage: mask)
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 3])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.5])
            .cropped(to: extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            throw ImageProcessingError.filterUnavailable("CIBlendWithMask")
        }
        blend.setValue(blurred, forKey: kCIInputImageKey)
        blend.setValue(original, forKey: kCIInputBackgroundImageKey)
        blend.setValue(softMask, forKey: kCIInputMaskImageKey)
        guard let output = blend.outputImage else { throw ImageProcessingError.renderFailed }
        let prepared = try renderer.render(output, in: extent)
        return try renderer.resized(
            prepared,
            to: PixelSize(width: inputSize, height: inputSize)
        )
    }

    private func composite(
        generated: CGImage,
        original: CGImage,
        originalCrop: CGImage,
        maskCrop: CGImage,
        rect: CGRect
    ) throws -> CGImage {
        let restored = try renderer.resized(
            generated,
            to: PixelSize(width: Int(rect.width), height: Int(rect.height))
        )
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            throw ImageProcessingError.filterUnavailable("CIBlendWithMask")
        }
        filter.setValue(CIImage(cgImage: restored), forKey: kCIInputImageKey)
        filter.setValue(CIImage(cgImage: originalCrop), forKey: kCIInputBackgroundImageKey)
        let blendMask = CIImage(cgImage: maskCrop)
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 3])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.5])
            .cropped(to: CIImage(cgImage: originalCrop).extent)
        filter.setValue(blendMask, forKey: kCIInputMaskImageKey)
        guard let output = filter.outputImage else { throw ImageProcessingError.renderFailed }
        let crop = try renderer.render(output)

        guard let context = CGContext(
            data: nil,
            width: original.width,
            height: original.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CoreMLImageError.allocationFailed
        }
        context.draw(original, in: CGRect(x: 0, y: 0, width: original.width, height: original.height))
        context.draw(
            crop,
            in: CGRect(
                x: rect.minX,
                y: CGFloat(original.height) - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        )
        guard let result = context.makeImage() else { throw ImageProcessingError.renderFailed }
        return result
    }
}
