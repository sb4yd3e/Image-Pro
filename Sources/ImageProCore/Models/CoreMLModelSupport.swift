import CoreGraphics
import CoreML
import Foundation

public enum CoreMLImageError: Error {
    case modelNotFound(String)
    case featureMissing(String)
    case unsupportedArrayType
    case allocationFailed
}

extension CoreMLImageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .modelNotFound(name):
            "The offline model “\(name)” is missing from the app bundle."
        case let .featureMissing(name) where name == "non-empty mask":
            "The mask has no painted area. Choose Add Mask and paint the object first."
        case let .featureMissing(name):
            "The AI model did not return its required “\(name)” output."
        case .unsupportedArrayType:
            "The bundled AI model uses an unsupported data format."
        case .allocationFailed:
            "There is not enough memory to prepare this AI operation. Try a smaller image or close other apps."
        }
    }
}

public enum CoreMLModelSupport {
    public static func bundledModel(named name: String, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: name, withExtension: "mlmodelc", subdirectory: "Models")
            ?? bundle.resourceURL?
                .appendingPathComponent("Models/\(name).mlmodelc")
                .existingDirectory
    }

    public static func loadModel(at url: URL, computeUnits: MLComputeUnits = .cpuAndGPU) throws -> MLModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        if url.pathExtension == "mlmodelc" {
            return try MLModel(contentsOf: url, configuration: configuration)
        }
        let compiledURL = try MLModel.compileModel(at: url)
        return try MLModel(contentsOf: compiledURL, configuration: configuration)
    }

    static func rgbaBytes(from image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CoreMLImageError.allocationFailed
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    static func rgbMultiArray(from image: CGImage, size: Int, dataType: MLMultiArrayDataType) throws -> MLMultiArray {
        let rgba = try rgbaBytes(from: image, width: size, height: size)
        let array = try MLMultiArray(shape: [1, 3, NSNumber(value: size), NSNumber(value: size)], dataType: dataType)
        let channelStride = size * size
        switch dataType {
        case .float16:
            let pointer = array.dataPointer.bindMemory(to: Float16.self, capacity: channelStride * 3)
            for pixel in 0..<channelStride {
                pointer[pixel] = Float16(Float(rgba[pixel * 4]) / 255)
                pointer[channelStride + pixel] = Float16(Float(rgba[pixel * 4 + 1]) / 255)
                pointer[channelStride * 2 + pixel] = Float16(Float(rgba[pixel * 4 + 2]) / 255)
            }
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: channelStride * 3)
            for pixel in 0..<channelStride {
                pointer[pixel] = Float(rgba[pixel * 4]) / 255
                pointer[channelStride + pixel] = Float(rgba[pixel * 4 + 1]) / 255
                pointer[channelStride * 2 + pixel] = Float(rgba[pixel * 4 + 2]) / 255
            }
        default:
            throw CoreMLImageError.unsupportedArrayType
        }
        return array
    }

    static func cgImage(from array: MLMultiArray, width: Int, height: Int) throws -> CGImage {
        let pixelCount = width * height
        var rgba = [UInt8](repeating: 255, count: pixelCount * 4)

        func byte(_ value: Float) -> UInt8 {
            UInt8((min(max(value, 0), 1) * 255).rounded())
        }

        switch array.dataType {
        case .float16:
            let pointer = array.dataPointer.bindMemory(to: Float16.self, capacity: pixelCount * 3)
            for pixel in 0..<pixelCount {
                rgba[pixel * 4] = byte(Float(pointer[pixel]))
                rgba[pixel * 4 + 1] = byte(Float(pointer[pixelCount + pixel]))
                rgba[pixel * 4 + 2] = byte(Float(pointer[pixelCount * 2 + pixel]))
            }
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: pixelCount * 3)
            for pixel in 0..<pixelCount {
                rgba[pixel * 4] = byte(pointer[pixel])
                rgba[pixel * 4 + 1] = byte(pointer[pixelCount + pixel])
                rgba[pixel * 4 + 2] = byte(pointer[pixelCount * 2 + pixel])
            }
        default:
            throw CoreMLImageError.unsupportedArrayType
        }

        let data = Data(rgba)
        guard
            let provider = CGDataProvider(data: data as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else {
            throw CoreMLImageError.allocationFailed
        }
        return image
    }
}

private extension URL {
    var existingDirectory: URL? {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? self
            : nil
    }
}
