import CoreGraphics
import CoreImage
import CoreML
import Foundation

public struct ContextCropPlanner {
    public static func contextRect(mask: CGImage, imageSize: PixelSize, expansion: Double = 2) throws -> CGRect {
        let bytes = try CoreMLModelSupport.rgbaBytes(from: mask, width: mask.width, height: mask.height)
        var minX = mask.width
        var minY = mask.height
        var maxX = -1
        var maxY = -1
        for y in 0..<mask.height {
            for x in 0..<mask.width where bytes[(y * mask.width + x) * 4] > 16 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else {
            throw CoreMLImageError.featureMissing("non-empty mask")
        }

        let scaleX = Double(imageSize.width) / Double(mask.width)
        let scaleY = Double(imageSize.height) / Double(mask.height)
        let centerX = (Double(minX + maxX + 1) / 2) * scaleX
        let centerY = (Double(minY + maxY + 1) / 2) * scaleY
        let contentWidth = Double(maxX - minX + 1) * scaleX
        let contentHeight = Double(maxY - minY + 1) * scaleY
        let side = min(
            Double(max(imageSize.width, imageSize.height)),
            max(256, max(contentWidth, contentHeight) * expansion)
        )
        let x = min(max(centerX - side / 2, 0), max(0, Double(imageSize.width) - side))
        let y = min(max(centerY - side / 2, 0), max(0, Double(imageSize.height) - side))
        return CGRect(x: x, y: y, width: min(side, Double(imageSize.width)), height: min(side, Double(imageSize.height))).integral
    }
}

public final class LaMaInpaintingProvider {
    private static let inputSize = 512
    private let model: MLModel
    private let renderer: CoreImageRenderer

    public init(modelURL: URL, renderer: CoreImageRenderer = .shared) throws {
        model = try CoreMLModelSupport.loadModel(at: modelURL)
        self.renderer = renderer
    }

    public func inpaint(image: CGImage, mask: CGImage) throws -> CGImage {
        let imageSize = PixelSize(width: image.width, height: image.height)
        let rect = try ContextCropPlanner.contextRect(mask: mask, imageSize: imageSize, expansion: 2.75)
        guard
            let imageCrop = image.cropping(to: rect),
            let maskCrop = mask.cropping(to: rect)
        else {
            throw ImageProcessingError.renderFailed
        }
        let maskRadius = max(2, min(10, min(rect.width, rect.height) * 0.008))
        let expandedMaskImage = CIImage(cgImage: maskCrop)
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: maskRadius])
            .cropped(to: CIImage(cgImage: imageCrop).extent)
        let expandedMask = try renderer.render(expandedMaskImage, in: expandedMaskImage.extent)
        let resizedImage = try renderer.resized(imageCrop, to: PixelSize(width: Self.inputSize, height: Self.inputSize))
        let resizedMask = try renderer.resized(expandedMask, to: PixelSize(width: Self.inputSize, height: Self.inputSize))
        let generated = try predict(image: resizedImage, mask: resizedMask)
        let restored = try renderer.resized(
            generated,
            to: PixelSize(width: Int(rect.width), height: Int(rect.height))
        )

        let foreground = CIImage(cgImage: restored)
        let background = CIImage(cgImage: imageCrop)
        let blendMask = CIImage(cgImage: expandedMask)
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(2, maskRadius * 0.65)])
            .cropped(to: background.extent)
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            throw ImageProcessingError.filterUnavailable("CIBlendWithMask")
        }
        filter.setValue(foreground, forKey: kCIInputImageKey)
        filter.setValue(background, forKey: kCIInputBackgroundImageKey)
        filter.setValue(blendMask, forKey: kCIInputMaskImageKey)
        guard let blended = filter.outputImage else { throw ImageProcessingError.renderFailed }
        let compositeCrop = try renderer.render(blended, in: background.extent)

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CoreMLImageError.allocationFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let drawRect = CGRect(x: rect.minX, y: CGFloat(image.height) - rect.maxY, width: rect.width, height: rect.height)
        context.draw(compositeCrop, in: drawRect)
        guard let result = context.makeImage() else { throw ImageProcessingError.renderFailed }
        return result
    }

    private func predict(image: CGImage, mask: CGImage) throws -> CGImage {
        let imageArray = try CoreMLModelSupport.rgbMultiArray(from: image, size: Self.inputSize, dataType: .float32)
        let maskBytes = try CoreMLModelSupport.rgbaBytes(from: mask, width: Self.inputSize, height: Self.inputSize)
        let maskArray = try MLMultiArray(
            shape: [1, 1, NSNumber(value: Self.inputSize), NSNumber(value: Self.inputSize)],
            dataType: .float32
        )
        let pointer = maskArray.dataPointer.bindMemory(to: Float.self, capacity: Self.inputSize * Self.inputSize)
        for pixel in 0..<(Self.inputSize * Self.inputSize) {
            pointer[pixel] = maskBytes[pixel * 4] > 127 ? 1 : 0
        }
        let features = try MLDictionaryFeatureProvider(dictionary: [
            "image": imageArray,
            "mask": maskArray
        ])
        let prediction = try model.prediction(from: features)
        guard let output = prediction.featureValue(for: "inpainted_image")?.multiArrayValue else {
            throw CoreMLImageError.featureMissing("inpainted_image")
        }
        return try CoreMLModelSupport.cgImage(from: output, width: Self.inputSize, height: Self.inputSize)
    }
}
