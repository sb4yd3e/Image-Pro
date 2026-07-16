import Foundation

public enum ModelCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case erase
    case generate
    case ocr
    case segmentation
    case upscale
}

public enum ModelEngine: String, Codable, CaseIterable, Hashable, Sendable {
    case coreML = "coreml"
    case appleStableDiffusion = "apple-stable-diffusion"
    case mlxSwift = "mlx-swift"
    case mlxVLM = "mlx-vlm"
}

public struct ModelPackageManifest: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let displayName: String
    public let version: String
    public let capabilities: [ModelCapability]
    public let engine: ModelEngine
    public let minimumOS: String
    public let minimumMemoryGB: Int
    public let license: String
    public let entrypoint: String
    public let installedBytes: Int64

    public init(
        schemaVersion: Int = 1,
        id: String,
        displayName: String,
        version: String,
        capabilities: [ModelCapability],
        engine: ModelEngine,
        minimumOS: String,
        minimumMemoryGB: Int,
        license: String,
        entrypoint: String,
        installedBytes: Int64
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.version = version
        self.capabilities = capabilities
        self.engine = engine
        self.minimumOS = minimumOS
        self.minimumMemoryGB = minimumMemoryGB
        self.license = license
        self.entrypoint = entrypoint
        self.installedBytes = installedBytes
    }
}

public struct ModelCatalog: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let updatedAt: String
    public let packages: [ModelCatalogItem]

    public init(schemaVersion: Int = 1, updatedAt: String, packages: [ModelCatalogItem]) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.packages = packages
    }
}

public struct ModelCatalogItem: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(package.id)-\(package.version)" }
    public let package: ModelPackageManifest
    public let archiveURL: URL
    public let archiveSHA256: String
    public let archiveBytes: Int64
    public let releaseNotes: String?

    public init(
        package: ModelPackageManifest,
        archiveURL: URL,
        archiveSHA256: String,
        archiveBytes: Int64,
        releaseNotes: String? = nil
    ) {
        self.package = package
        self.archiveURL = archiveURL
        self.archiveSHA256 = archiveSHA256.lowercased()
        self.archiveBytes = archiveBytes
        self.releaseNotes = releaseNotes
    }
}

public struct InstalledModel: Hashable, Identifiable, Sendable {
    public var id: String { "\(manifest.id)-\(manifest.version)" }
    public let manifest: ModelPackageManifest
    public let rootURL: URL
    public let activeCapabilities: Set<ModelCapability>

    public init(
        manifest: ModelPackageManifest,
        rootURL: URL,
        activeCapabilities: Set<ModelCapability> = []
    ) {
        self.manifest = manifest
        self.rootURL = rootURL
        self.activeCapabilities = activeCapabilities
    }
}

public enum ModelPackageError: Error, Equatable {
    case invalidPackage
    case unsupportedSchema(Int)
    case invalidIdentifier
    case unsafePath(String)
    case missingEntrypoint(String)
    case unsupportedCapability
    case archiveExtractionFailed
    case activeModelCannotBeRemoved
    case catalogChecksumMismatch
    case incompatibleOS(String)
    case insufficientMemory(Int)
}

extension ModelPackageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPackage:
            "This is not a valid Image Pro model package."
        case let .unsupportedSchema(version):
            "This model package uses unsupported schema version \(version). Update Image Pro first."
        case .invalidIdentifier:
            "The model package has an invalid identifier or version."
        case let .unsafePath(path):
            "The model package contains an unsafe path: \(path)"
        case let .missingEntrypoint(path):
            "The model entrypoint is missing: \(path)"
        case .unsupportedCapability:
            "This model does not support the selected feature."
        case .archiveExtractionFailed:
            "The model archive could not be extracted."
        case .activeModelCannotBeRemoved:
            "Choose another model for this feature before removing the active model."
        case .catalogChecksumMismatch:
            "The downloaded model does not match the catalog checksum."
        case let .incompatibleOS(version):
            "This model requires macOS \(version) or later."
        case let .insufficientMemory(gigabytes):
            "This model requires at least \(gigabytes) GB of memory."
        }
    }
}

private struct ActiveModelRecord: Codable, Hashable {
    let id: String
    let version: String
}

private struct ActiveModelFile: Codable {
    var capabilities: [String: ActiveModelRecord]
}

public final class ModelStore: @unchecked Sendable {
    public static let manifestFilename = "model.json"

    public let rootURL: URL
    private let fileManager: FileManager
    private var packagesURL: URL { rootURL.appendingPathComponent("Packages", isDirectory: true) }
    private var stagingURL: URL { rootURL.appendingPathComponent("Staging", isDirectory: true) }
    private var activeFileURL: URL { rootURL.appendingPathComponent("active.json") }

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("Image Pro", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    public func installedModels() throws -> [InstalledModel] {
        try prepareDirectories()
        let active = try readActiveFile()
        let identifiers = try directoryContents(at: packagesURL)
        var result: [InstalledModel] = []
        for identifierURL in identifiers {
            for versionURL in try directoryContents(at: identifierURL) {
                let manifestURL = versionURL.appendingPathComponent(Self.manifestFilename)
                guard fileManager.fileExists(atPath: manifestURL.path) else { continue }
                let manifest = try decodeManifest(at: manifestURL)
                let selected = Set(manifest.capabilities.filter { capability in
                    active.capabilities[capability.rawValue] == ActiveModelRecord(
                        id: manifest.id,
                        version: manifest.version
                    )
                })
                result.append(InstalledModel(
                    manifest: manifest,
                    rootURL: versionURL,
                    activeCapabilities: selected
                ))
            }
        }
        return result.sorted {
            ($0.manifest.displayName, $0.manifest.version) < ($1.manifest.displayName, $1.manifest.version)
        }
    }

    public func resolveActiveModel(for capability: ModelCapability) throws -> URL? {
        try activeModel(for: capability).map {
            try validatedEntrypoint(manifest: $0.manifest, packageRoot: $0.rootURL)
        }
    }

    public func activeModel(for capability: ModelCapability) throws -> InstalledModel? {
        let active = try readActiveFile()
        guard let record = active.capabilities[capability.rawValue] else { return nil }
        let root = packageURL(id: record.id, version: record.version)
        let manifestURL = root.appendingPathComponent(Self.manifestFilename)
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        let manifest = try decodeManifest(at: manifestURL)
        guard manifest.capabilities.contains(capability) else { return nil }
        _ = try validatedEntrypoint(manifest: manifest, packageRoot: root)
        return InstalledModel(
            manifest: manifest,
            rootURL: root,
            activeCapabilities: [capability]
        )
    }

    @discardableResult
    public func installPackage(at sourceURL: URL) throws -> InstalledModel {
        try prepareDirectories()
        let temporary = stagingURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporary) }

        let unpackedRoot: URL
        if sourceURL.pathExtension.lowercased() == "zip" {
            try extractArchive(sourceURL, to: temporary)
            unpackedRoot = try locatePackageRoot(inside: temporary)
        } else {
            unpackedRoot = try locatePackageRoot(inside: sourceURL)
        }

        let manifest = try decodeManifest(
            at: unpackedRoot.appendingPathComponent(Self.manifestFilename)
        )
        try validate(manifest: manifest, packageRoot: unpackedRoot)

        let target = packageURL(id: manifest.id, version: manifest.version)
        let stagedCopy = temporary.appendingPathComponent("validated.imagepromodel", isDirectory: true)
        if stagedCopy.standardizedFileURL != unpackedRoot.standardizedFileURL {
            try fileManager.copyItem(at: unpackedRoot, to: stagedCopy)
        }
        let source = stagedCopy.standardizedFileURL == unpackedRoot.standardizedFileURL
            ? unpackedRoot
            : stagedCopy
        try fileManager.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.moveItem(at: source, to: target)

        var active = try readActiveFile()
        for capability in manifest.capabilities where active.capabilities[capability.rawValue] == nil {
            active.capabilities[capability.rawValue] = ActiveModelRecord(id: manifest.id, version: manifest.version)
        }
        try writeActiveFile(active)
        let selected = Set(manifest.capabilities.filter {
            active.capabilities[$0.rawValue] == ActiveModelRecord(id: manifest.id, version: manifest.version)
        })
        return InstalledModel(manifest: manifest, rootURL: target, activeCapabilities: selected)
    }

    public func activate(modelID: String, version: String, for capability: ModelCapability) throws {
        let root = packageURL(id: modelID, version: version)
        let manifest = try decodeManifest(at: root.appendingPathComponent(Self.manifestFilename))
        guard manifest.capabilities.contains(capability) else {
            throw ModelPackageError.unsupportedCapability
        }
        _ = try validatedEntrypoint(manifest: manifest, packageRoot: root)
        var active = try readActiveFile()
        active.capabilities[capability.rawValue] = ActiveModelRecord(id: modelID, version: version)
        try writeActiveFile(active)
    }

    public func remove(modelID: String, version: String) throws {
        var active = try readActiveFile()
        let record = ActiveModelRecord(id: modelID, version: version)
        let affected = active.capabilities.filter { $0.value == record }.map(\.key)
        if !affected.isEmpty {
            let alternatives = try installedModels().filter {
                $0.manifest.id != modelID || $0.manifest.version != version
            }
            for rawCapability in affected {
                guard
                    let capability = ModelCapability(rawValue: rawCapability),
                    let replacement = alternatives.first(where: { $0.manifest.capabilities.contains(capability) })
                else {
                    active.capabilities.removeValue(forKey: rawCapability)
                    continue
                }
                active.capabilities[rawCapability] = ActiveModelRecord(
                    id: replacement.manifest.id,
                    version: replacement.manifest.version
                )
            }
        }
        try writeActiveFile(active)
        let target = packageURL(id: modelID, version: version)
        guard fileManager.fileExists(atPath: target.path) else { return }
        try fileManager.removeItem(at: target)
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: packagesURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
    }

    private func locatePackageRoot(inside url: URL) throws -> URL {
        let direct = url.appendingPathComponent(Self.manifestFilename)
        if fileManager.fileExists(atPath: direct.path) { return url }
        let candidates = try directoryContents(at: url).filter {
            fileManager.fileExists(atPath: $0.appendingPathComponent(Self.manifestFilename).path)
        }
        guard candidates.count == 1, let candidate = candidates.first else {
            throw ModelPackageError.invalidPackage
        }
        return candidate
    }

    private func validate(manifest: ModelPackageManifest, packageRoot: URL) throws {
        guard manifest.schemaVersion == 1 else {
            throw ModelPackageError.unsupportedSchema(manifest.schemaVersion)
        }
        guard
            isSafeComponent(manifest.id),
            isSafeComponent(manifest.version),
            !manifest.capabilities.isEmpty
        else { throw ModelPackageError.invalidIdentifier }
        let requiredOS = OperatingSystemVersion(versionString: manifest.minimumOS)
        if !ProcessInfo.processInfo.isOperatingSystemAtLeast(requiredOS) {
            throw ModelPackageError.incompatibleOS(manifest.minimumOS)
        }
        let physicalMemoryGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        if physicalMemoryGB < manifest.minimumMemoryGB {
            throw ModelPackageError.insufficientMemory(manifest.minimumMemoryGB)
        }
        _ = try validatedEntrypoint(manifest: manifest, packageRoot: packageRoot)

        if let enumerator = fileManager.enumerator(
            at: packageRoot,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let item as URL in enumerator {
                let values = try item.resourceValues(forKeys: [.isSymbolicLinkKey])
                if values.isSymbolicLink == true {
                    throw ModelPackageError.unsafePath(item.lastPathComponent)
                }
            }
        }
    }

    private func validatedEntrypoint(
        manifest: ModelPackageManifest,
        packageRoot: URL
    ) throws -> URL {
        guard !manifest.entrypoint.isEmpty, !manifest.entrypoint.hasPrefix("/") else {
            throw ModelPackageError.unsafePath(manifest.entrypoint)
        }
        let root = packageRoot.standardizedFileURL
        let entrypoint = root.appendingPathComponent(manifest.entrypoint).standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard entrypoint.path.hasPrefix(prefix) else {
            throw ModelPackageError.unsafePath(manifest.entrypoint)
        }
        guard fileManager.fileExists(atPath: entrypoint.path) else {
            throw ModelPackageError.missingEntrypoint(manifest.entrypoint)
        }
        return entrypoint
    }

    private func extractArchive(_ archiveURL: URL, to destination: URL) throws {
        try validateArchiveEntries(archiveURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ModelPackageError.archiveExtractionFailed
        }
    }

    private func validateArchiveEntries(_ archiveURL: URL) throws {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", archiveURL.path]
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let listing = String(data: data, encoding: .utf8) else {
            throw ModelPackageError.archiveExtractionFailed
        }
        for path in listing.split(whereSeparator: \.isNewline).map(String.init) {
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            if path.hasPrefix("/") || components.contains("..") {
                throw ModelPackageError.unsafePath(path)
            }
        }
    }

    private func packageURL(id: String, version: String) -> URL {
        packagesURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
    }

    private func decodeManifest(at url: URL) throws -> ModelPackageManifest {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ModelPackageError.invalidPackage
        }
        return try JSONDecoder().decode(ModelPackageManifest.self, from: Data(contentsOf: url))
    }

    private func readActiveFile() throws -> ActiveModelFile {
        guard fileManager.fileExists(atPath: activeFileURL.path) else {
            return ActiveModelFile(capabilities: [:])
        }
        return try JSONDecoder().decode(ActiveModelFile.self, from: Data(contentsOf: activeFileURL))
    }

    private func writeActiveFile(_ file: ActiveModelFile) throws {
        try prepareDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: activeFileURL, options: .atomic)
    }

    private func directoryContents(at url: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private func isSafeComponent(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." &&
            value.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
    }
}

private extension OperatingSystemVersion {
    init(versionString: String) {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        self.init(
            majorVersion: components.indices.contains(0) ? components[0] : 0,
            minorVersion: components.indices.contains(1) ? components[1] : 0,
            patchVersion: components.indices.contains(2) ? components[2] : 0
        )
    }
}

public enum InstalledModelLocator {
    public static func model(
        for capability: ModelCapability,
        store: ModelStore = ModelStore()
    ) -> InstalledModel? {
        try? store.activeModel(for: capability)
    }

    public static func url(
        for capability: ModelCapability,
        store: ModelStore = ModelStore()
    ) -> URL? {
        try? store.resolveActiveModel(for: capability)
    }
}
