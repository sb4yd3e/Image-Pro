import Foundation
import UniformTypeIdentifiers

public struct ImageAuditRecord: Codable, Sendable {
    public var path: String
    public var sourceBytes: Int?
    public var width: Int?
    public var height: Int?
    public var previewWidth: Int?
    public var previewHeight: Int?
    public var suggestedFormat: String?
    public var error: String?
}

public struct ImageFolderAuditReport: Codable, Sendable {
    public var generatedAt: Date
    public var rootPath: String
    public var total: Int
    public var passed: Int
    public var failed: Int
    public var records: [ImageAuditRecord]
}

public enum ImageFolderAuditor {
    public static func audit(directory: URL, previewMaxDimension: Int = 2_048) -> ImageFolderAuditReport {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentTypeKey]
        let urls = (FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )?.allObjects as? [URL] ?? []).filter { url in
            guard let values = try? url.resourceValues(forKeys: keys) else { return false }
            return values.isRegularFile == true && values.contentType?.conforms(to: .image) == true
        }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        let records = urls.map { url -> ImageAuditRecord in
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let info = try ImageIOService.inspect(data: data)
                let preview = try ImageIOService.preview(data: data, maxPixelDimension: previewMaxDimension)
                return ImageAuditRecord(
                    path: url.path,
                    sourceBytes: data.count,
                    width: info.pixelSize.width,
                    height: info.pixelSize.height,
                    previewWidth: preview.width,
                    previewHeight: preview.height,
                    suggestedFormat: ImageFormatClassifier.suggestedFormat(for: preview).displayName,
                    error: nil
                )
            } catch {
                return ImageAuditRecord(
                    path: url.path,
                    sourceBytes: nil,
                    width: nil,
                    height: nil,
                    previewWidth: nil,
                    previewHeight: nil,
                    suggestedFormat: nil,
                    error: error.localizedDescription
                )
            }
        }
        let passed = records.filter { $0.error == nil }.count
        return ImageFolderAuditReport(
            generatedAt: Date(),
            rootPath: directory.path,
            total: records.count,
            passed: passed,
            failed: records.count - passed,
            records: records
        )
    }
}
