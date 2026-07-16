import CoreGraphics
import CoreImage
import CoreML
import Foundation

public protocol SuperResolutionProviding: AnyObject {
    func upscale(_ image: CGImage, scale: Int, progress: (Double) -> Void) throws -> CGImage
}

public extension SuperResolutionProviding {
    func upscale(_ image: CGImage, progress: (Double) -> Void = { _ in }) throws -> CGImage {
        try upscale(image, scale: 4, progress: progress)
    }
}

@available(macOS 15.0, *)
public final class RealESRGANProvider: SuperResolutionProviding {
    public static let scale = 4
    private static let tileSize = 256
    private static let overlap = 16

    private let model: MLModel
    private let renderer: CoreImageRenderer

    public init(modelURL: URL, renderer: CoreImageRenderer = .shared) throws {
        model = try CoreMLModelSupport.loadModel(at: modelURL)
        self.renderer = renderer
    }

    public func upscale(
        _ image: CGImage,
        scale requestedScale: Int,
        progress: (Double) -> Void = { _ in }
    ) throws -> CGImage {
        let outputScale = requestedScale == 2 ? 2 : Self.scale
        let step = Self.tileSize - Self.overlap * 2
        let columns = Int(ceil(Double(image.width) / Double(step)))
        let rows = Int(ceil(Double(image.height) / Double(step)))
        let outputWidth = image.width * outputScale
        let outputHeight = image.height * outputScale
        guard let outputContext = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CoreMLImageError.allocationFailed
        }

        let source = CIImage(cgImage: image).clampedToExtent()
        var completed = 0
        for row in 0..<rows {
            for column in 0..<columns {
                try Task.checkCancellation()
                let cellX = column * step
                let cellY = row * step
                let cellWidth = min(step, image.width - cellX)
                let cellHeight = min(step, image.height - cellY)
                let tileRect = CGRect(
                    x: cellX - Self.overlap,
                    y: cellY - Self.overlap,
                    width: Self.tileSize,
                    height: Self.tileSize
                )
                let tile = try renderer.render(source.cropped(to: tileRect), in: tileRect)
                let enhanced = try predict(tile)
                let centralRect = CGRect(
                    x: Self.overlap * Self.scale,
                    // Core Image uses a bottom-left origin while CGImage.cropping uses
                    // top-left raster coordinates. The final/short row therefore has
                    // a dynamic top inset instead of a fixed overlap inset.
                    y: (Self.tileSize - Self.overlap - cellHeight) * Self.scale,
                    width: cellWidth * Self.scale,
                    height: cellHeight * Self.scale
                )
                guard var central = enhanced.cropping(to: centralRect) else {
                    throw ImageProcessingError.renderFailed
                }
                if outputScale != Self.scale {
                    central = try renderer.resized(
                        central,
                        to: PixelSize(width: cellWidth * outputScale, height: cellHeight * outputScale)
                    )
                }
                outputContext.draw(
                    central,
                    in: CGRect(
                        x: cellX * outputScale,
                        y: cellY * outputScale,
                        width: cellWidth * outputScale,
                        height: cellHeight * outputScale
                    )
                )
                completed += 1
                progress(Double(completed) / Double(rows * columns))
            }
        }

        guard let output = outputContext.makeImage() else {
            throw ImageProcessingError.renderFailed
        }
        return try restoredAlphaIfNeeded(
            source: image,
            enhanced: output,
            size: PixelSize(width: outputWidth, height: outputHeight)
        )
    }

    private func restoredAlphaIfNeeded(
        source: CGImage,
        enhanced: CGImage,
        size: PixelSize
    ) throws -> CGImage {
        guard ImageIOService.hasAlpha(source) else { return enhanced }
        let alphaVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let zeroVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        let alphaImage = CIImage(cgImage: source).applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": alphaVector,
            "inputGVector": alphaVector,
            "inputBVector": alphaVector,
            "inputAVector": alphaVector,
            "inputBiasVector": zeroVector
        ])
        let alphaMask = try renderer.render(alphaImage)
        let scaledMask = try renderer.resized(alphaMask, to: size)
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            throw ImageProcessingError.filterUnavailable("CIBlendWithMask")
        }
        let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        filter.setValue(CIImage(cgImage: enhanced), forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: .clear).cropped(to: bounds), forKey: kCIInputBackgroundImageKey)
        filter.setValue(CIImage(cgImage: scaledMask), forKey: kCIInputMaskImageKey)
        guard let composited = filter.outputImage else { throw ImageProcessingError.renderFailed }
        return try renderer.render(composited, in: bounds)
    }

    private func predict(_ tile: CGImage) throws -> CGImage {
        let input = try CoreMLModelSupport.rgbMultiArray(from: tile, size: Self.tileSize, dataType: .float16)
        let provider = try MLDictionaryFeatureProvider(dictionary: ["input": input])
        let prediction = try model.prediction(from: provider)
        guard let output = prediction.featureValue(for: "output")?.multiArrayValue else {
            throw CoreMLImageError.featureMissing("output")
        }
        return try CoreMLModelSupport.cgImage(from: output, width: 1024, height: 1024)
    }
}
