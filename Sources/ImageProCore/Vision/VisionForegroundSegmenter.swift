import CoreGraphics
import CoreVideo
import Foundation
import Vision

@available(macOS 14.0, *)
public final class VisionForegroundSegmenter {
    private static let analysisMaxDimension = 2_048

    public init() {}

    public func availableInstances(for image: CGImage) throws -> IndexSet {
        if let (_, observation) = try? instanceObservation(for: image) {
            return observation.allInstances
        }
        _ = try fallbackMask(for: image)
        return IndexSet(integer: 1)
    }

    public func maskAndInstances(
        for image: CGImage,
        selectedInstances requestedInstances: IndexSet = IndexSet()
    ) throws -> (mask: CVPixelBuffer, availableInstances: IndexSet, selectedInstances: IndexSet) {
        if let (handler, observation) = try? instanceObservation(for: image) {
            let selected = requestedInstances.isEmpty
                ? observation.allInstances
                : requestedInstances.intersection(observation.allInstances)
            if !selected.isEmpty,
               let mask = try? observation.generateScaledMaskForImage(
                   forInstances: selected,
                   from: handler
               ) {
                return (mask, observation.allInstances, selected)
            }
        }

        let fallbackInstance = IndexSet(integer: 1)
        let selected = requestedInstances.isEmpty
            ? fallbackInstance
            : requestedInstances.intersection(fallbackInstance)
        guard !selected.isEmpty else { throw VisionForegroundError.noForegroundFound }
        return (try fallbackMask(for: image), fallbackInstance, selected)
    }

    public func mask(for image: CGImage, instances: IndexSet = IndexSet()) throws -> CVPixelBuffer {
        if let (handler, observation) = try? instanceObservation(for: image) {
            let selectedInstances = instances.isEmpty
                ? observation.allInstances
                : instances.intersection(observation.allInstances)
            if !selectedInstances.isEmpty,
               let mask = try? observation.generateScaledMaskForImage(
                   forInstances: selectedInstances,
                   from: handler
               ) {
                return mask
            }
        }
        return try fallbackMask(for: image)
    }

    private func instanceObservation(
        for image: CGImage
    ) throws -> (VNImageRequestHandler, VNInstanceMaskObservation) {
        if let result = try? performInstanceRequest(on: image) {
            return result
        }
        let analysisImage = try resizedForAnalysis(image)
        guard analysisImage.width != image.width || analysisImage.height != image.height else {
            throw VisionForegroundError.noForegroundFound
        }
        return try performInstanceRequest(on: analysisImage)
    }

    private func performInstanceRequest(
        on image: CGImage
    ) throws -> (VNImageRequestHandler, VNInstanceMaskObservation) {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first else {
            throw VisionForegroundError.noForegroundFound
        }
        return (handler, observation)
    }

    private func fallbackMask(for image: CGImage) throws -> CVPixelBuffer {
        let analysisImage = try resizedForAnalysis(image)

        if let personMask = try? personSegmentationMask(for: analysisImage),
           containsForeground(personMask) {
            return personMask
        }
        if let graphicMask = try? edgeConnectedBackgroundMask(for: analysisImage) {
            return graphicMask
        }
        if let objectness = try? saliencyMask(
            for: analysisImage,
            request: VNGenerateObjectnessBasedSaliencyImageRequest()
        ) {
            return objectness
        }
        if let attention = try? saliencyMask(
            for: analysisImage,
            request: VNGenerateAttentionBasedSaliencyImageRequest()
        ) {
            return attention
        }
        throw VisionForegroundError.noForegroundFound
    }

    private func resizedForAnalysis(_ image: CGImage) throws -> CGImage {
        let maximum = max(image.width, image.height)
        guard maximum > Self.analysisMaxDimension else { return image }
        let scale = Double(Self.analysisMaxDimension) / Double(maximum)
        return try CoreImageRenderer.shared.resized(
            image,
            to: PixelSize(
                width: max(1, Int((Double(image.width) * scale).rounded())),
                height: max(1, Int((Double(image.height) * scale).rounded()))
            )
        )
    }

    private func personSegmentationMask(for image: CGImage) throws -> CVPixelBuffer {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let result = request.results?.first else {
            throw VisionForegroundError.noForegroundFound
        }
        return result.pixelBuffer
    }

    /// Builds a foreground mask by flood-filling a coherent background inward
    /// from the image edges. This covers logos, posters, product cards, and
    /// other flat graphics for which Vision does not return an instance mask.
    private func edgeConnectedBackgroundMask(for image: CGImage) throws -> CVPixelBuffer {
        let workingImage: CGImage
        let maximum = max(image.width, image.height)
        if maximum > 1_280 {
            let scale = 1_280.0 / Double(maximum)
            workingImage = try CoreImageRenderer.shared.resized(
                image,
                to: PixelSize(
                    width: max(1, Int((Double(image.width) * scale).rounded())),
                    height: max(1, Int((Double(image.height) * scale).rounded()))
                )
            )
        } else {
            workingImage = image
        }

        let width = workingImage.width
        let height = workingImage.height
        let rgba = try CoreMLModelSupport.rgbaBytes(
            from: workingImage,
            width: width,
            height: height
        )
        let edgeIndices = sampledEdgeIndices(width: width, height: height)
        guard !edgeIndices.isEmpty else { throw VisionForegroundError.noForegroundFound }

        var average = (red: 0.0, green: 0.0, blue: 0.0)
        for index in edgeIndices {
            average.red += Double(rgba[index * 4])
            average.green += Double(rgba[index * 4 + 1])
            average.blue += Double(rgba[index * 4 + 2])
        }
        let count = Double(edgeIndices.count)
        average.red /= count
        average.green /= count
        average.blue /= count

        let coherent = edgeIndices.filter {
            colorDistanceSquared(rgba, pixel: $0, color: average) <= 95 * 95
        }
        guard Double(coherent.count) / count >= 0.72 else {
            throw VisionForegroundError.noForegroundFound
        }
        var palette: [(UInt8, UInt8, UInt8)] = []
        for index in coherent {
            let offset = index * 4
            let color = (rgba[offset], rgba[offset + 1], rgba[offset + 2])
            let isRepresented = palette.contains { sample in
                let dr = Int(color.0) - Int(sample.0)
                let dg = Int(color.1) - Int(sample.1)
                let db = Int(color.2) - Int(sample.2)
                return dr * dr + dg * dg + db * db < 24 * 24
            }
            if !isRepresented { palette.append(color) }
            if palette.count == 16 { break }
        }

        var background = [UInt8](repeating: 0, count: width * height)
        var queue: [Int] = []
        queue.reserveCapacity(width * height / 2)
        for index in borderIndices(width: width, height: height)
        where isBackgroundCandidate(rgba, pixel: index, palette: palette) {
            if background[index] == 0 {
                background[index] = 1
                queue.append(index)
            }
        }
        guard !queue.isEmpty else { throw VisionForegroundError.noForegroundFound }

        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let x = current % width
            let y = current / width
            let neighbors = [
                x > 0 ? current - 1 : -1,
                x + 1 < width ? current + 1 : -1,
                y > 0 ? current - width : -1,
                y + 1 < height ? current + width : -1
            ]
            for neighbor in neighbors where neighbor >= 0 && background[neighbor] == 0 {
                guard localColorDistanceSquared(rgba, current, neighbor) <= 42 * 42,
                      isBackgroundCandidate(rgba, pixel: neighbor, palette: palette)
                else { continue }
                background[neighbor] = 1
                queue.append(neighbor)
            }
        }

        if ImageFormatClassifier.suggestedFormat(for: workingImage) == .png {
            for index in background.indices
            where isBackgroundCandidate(rgba, pixel: index, palette: palette) {
                background[index] = 1
            }
        }

        let foregroundCount = background.reduce(into: 0) { count, value in
            if value == 0 { count += 1 }
        }
        let foregroundRatio = Double(foregroundCount) / Double(max(1, background.count))
        guard foregroundRatio > 0.002, foregroundRatio < 0.98 else {
            throw VisionForegroundError.noForegroundFound
        }

        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            attributes,
            &buffer
        ) == kCVReturnSuccess, let buffer else {
            throw CoreMLImageError.allocationFailed
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw CoreMLImageError.allocationFailed
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let output = base.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                output[y * bytesPerRow + x] = background[y * width + x] == 1 ? 0 : 255
            }
        }
        return buffer
    }

    private func sampledEdgeIndices(width: Int, height: Int) -> [Int] {
        let step = max(1, min(width, height) / 48)
        var result: [Int] = []
        for x in stride(from: 0, to: width, by: step) {
            result.append(x)
            result.append((height - 1) * width + x)
        }
        for y in stride(from: 0, to: height, by: step) {
            result.append(y * width)
            result.append(y * width + width - 1)
        }
        return result
    }

    private func borderIndices(width: Int, height: Int) -> [Int] {
        var result = Array(0..<width)
        if height > 1 { result.append(contentsOf: ((height - 1) * width)..<(height * width)) }
        if height > 2 {
            for y in 1..<(height - 1) {
                result.append(y * width)
                if width > 1 { result.append(y * width + width - 1) }
            }
        }
        return result
    }

    private func isBackgroundCandidate(
        _ rgba: [UInt8],
        pixel: Int,
        palette: [(UInt8, UInt8, UInt8)]
    ) -> Bool {
        let offset = pixel * 4
        let red = Int(rgba[offset])
        let green = Int(rgba[offset + 1])
        let blue = Int(rgba[offset + 2])
        return palette.contains { sample in
            let dr = red - Int(sample.0)
            let dg = green - Int(sample.1)
            let db = blue - Int(sample.2)
            return dr * dr + dg * dg + db * db <= 88 * 88
        }
    }

    private func colorDistanceSquared(
        _ rgba: [UInt8],
        pixel: Int,
        color: (red: Double, green: Double, blue: Double)
    ) -> Double {
        let offset = pixel * 4
        let dr = Double(rgba[offset]) - color.red
        let dg = Double(rgba[offset + 1]) - color.green
        let db = Double(rgba[offset + 2]) - color.blue
        return dr * dr + dg * dg + db * db
    }

    private func localColorDistanceSquared(_ rgba: [UInt8], _ lhs: Int, _ rhs: Int) -> Int {
        let left = lhs * 4
        let right = rhs * 4
        let dr = Int(rgba[left]) - Int(rgba[right])
        let dg = Int(rgba[left + 1]) - Int(rgba[right + 1])
        let db = Int(rgba[left + 2]) - Int(rgba[right + 2])
        return dr * dr + dg * dg + db * db
    }

    private func saliencyMask<T: VNImageBasedRequest>(
        for image: CGImage,
        request: T
    ) throws -> CVPixelBuffer {
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard
            let observation = request.results?.first as? VNSaliencyImageObservation,
            !(observation.salientObjects ?? []).isEmpty
        else { throw VisionForegroundError.noForegroundFound }
        return observation.pixelBuffer
    }

    private func containsForeground(_ buffer: CVPixelBuffer) -> Bool {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8 else {
            return true
        }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return false }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let pointer = base.assumingMemoryBound(to: UInt8.self)
        let stepX = max(1, width / 128)
        let stepY = max(1, height / 128)
        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX)
            where pointer[y * bytesPerRow + x] > 16 {
                return true
            }
        }
        return false
    }
}

@available(macOS 14.0, *)
extension VisionForegroundSegmenter: ForegroundMaskProviding {}

public enum VisionForegroundError: Error, Equatable {
    case noForegroundFound
}

extension VisionForegroundError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noForegroundFound:
            "No clear foreground subject was found. Try Detect & Refine, crop closer to the subject, or use Erase for a flat graphic."
        }
    }
}
