import CoreGraphics
import Foundation
import Vision

public enum OCRRecognitionQuality: String, Codable, CaseIterable, Sendable {
    case fast
    case accurate
}

public struct OCRTextBlock: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var confidence: Float
    public var boundingBox: CGRect

    public init(id: UUID = UUID(), text: String, confidence: Float, boundingBox: CGRect) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct OCRResult: Codable, Hashable, Sendable {
    public var blocks: [OCRTextBlock]
    public var languages: [String]

    public init(blocks: [OCRTextBlock], languages: [String]) {
        self.blocks = blocks
        self.languages = languages
    }

    public var text: String {
        blocks.map(\.text).joined(separator: "\n")
    }

    public var averageConfidence: Float {
        guard !blocks.isEmpty else { return 0 }
        return blocks.reduce(0) { $0 + $1.confidence } / Float(blocks.count)
    }
}

public final class VisionTextRecognizer {
    public init() {}

    public func supportedLanguages(quality: OCRRecognitionQuality = .accurate) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = quality == .accurate ? .accurate : .fast
        return try request.supportedRecognitionLanguages().sorted()
    }

    public func recognize(
        image: CGImage,
        quality: OCRRecognitionQuality = .accurate,
        languages: [String] = [],
        usesLanguageCorrection: Bool = true
    ) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = quality == .accurate ? .accurate : .fast
        request.usesLanguageCorrection = usesLanguageCorrection
        request.automaticallyDetectsLanguage = languages.isEmpty

        let supported = try supportedLanguages(quality: quality)
        let selected = languages.filter { supported.contains($0) }
        if !selected.isEmpty {
            request.recognitionLanguages = selected
        }

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])

        let blocks = (request.results ?? []).compactMap { observation -> OCRTextBlock? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRTextBlock(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }.sorted { lhs, rhs in
            let rowTolerance = 0.02
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > rowTolerance {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        return OCRResult(blocks: blocks, languages: selected)
    }
}
