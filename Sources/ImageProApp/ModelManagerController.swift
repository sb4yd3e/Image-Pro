import AppKit
import Foundation
import ImageProCore

@MainActor
final class ModelManagerController: ObservableObject {
    static let catalogURL = URL(
        string: "https://raw.githubusercontent.com/sb4yd3e/Image-Pro/main/ModelCatalog/catalog.json"
    )!

    @Published private(set) var installedModels: [InstalledModel] = []
    @Published private(set) var catalogPackages: [ModelCatalogItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var workingPackageID: String?
    @Published private(set) var statusText = ModelManagerController.localized(
        english: "Models are downloaded separately from the app.",
        thai: "โมเดลถูกดาวน์โหลดแยกจากตัวแอป"
    )
    @Published var errorMessage: String?

    let store: ModelStore

    init(store: ModelStore = ModelStore()) {
        self.store = store
        loadBundledCatalog()
        loadCachedCatalog()
        reloadInstalled()
    }

    func reloadInstalled() {
        do {
            installedModels = try store.installedModels()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshCatalog() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        statusText = Self.localized(
            english: "Checking the model catalog…",
            thai: "กำลังตรวจรายการโมเดล…"
        )
        Task {
            defer { isRefreshing = false }
            do {
                var request = URLRequest(url: Self.catalogURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response, resource: .catalog)
                let catalog = try JSONDecoder().decode(ModelCatalog.self, from: data)
                guard catalog.schemaVersion == 1 else {
                    throw ModelPackageError.unsupportedSchema(catalog.schemaVersion)
                }
                catalogPackages = catalog.packages
                try? cacheCatalog(data)
                statusText = catalog.packages.isEmpty
                    ? Self.localized(
                        english: "No downloadable model packs have been published yet. You can import a local pack.",
                        thai: "ยังไม่มีแพ็กโมเดลออนไลน์ คุณยังนำเข้าแพ็กจากเครื่องได้"
                    )
                    : Self.localized(
                        english: "Model catalog updated \(catalog.updatedAt).",
                        thai: "อัปเดตรายการโมเดลแล้ว \(catalog.updatedAt)"
                    )
            } catch {
                // Keep the bundled/cached catalog and installed models usable. A missing
                // catalog is an expected deployment state, not a fatal app error.
                statusText = catalogFailureMessage(for: error)
            }
        }
    }

    func install(_ item: ModelCatalogItem) {
        guard workingPackageID == nil else { return }
        workingPackageID = item.id
        statusText = "Downloading \(item.package.displayName)…"
        Task {
            defer { workingPackageID = nil }
            do {
                let (temporaryURL, response) = try await URLSession.shared.download(from: item.archiveURL)
                try Self.validate(response: response, resource: .modelPack)
                // CFNetwork owns `temporaryURL` and may remove it as soon as the
                // download callback completes. Move it into our Application Support
                // staging area before hashing or handing work to a detached task.
                let stagedArchive = try persistDownloadedArchive(at: temporaryURL)
                defer { try? FileManager.default.removeItem(at: stagedArchive) }
                let expected = item.archiveSHA256
                let actual = try await Task.detached(priority: .utility) {
                    try ModelValidator.sha256(fileAt: stagedArchive)
                }.value
                guard !expected.isEmpty, actual == expected else {
                    throw ModelPackageError.catalogChecksumMismatch
                }
                statusText = "Validating and installing \(item.package.displayName)…"
                let installed = try await Task.detached(priority: .userInitiated) { [store] in
                    try store.installPackage(at: stagedArchive)
                }.value
                reloadInstalled()
                statusText = "Installed \(installed.manifest.displayName) \(installed.manifest.version)."
            } catch {
                errorMessage = modelDownloadFailureMessage(for: error)
                statusText = Self.localized(
                    english: "Model installation failed.",
                    thai: "ติดตั้งโมเดลไม่สำเร็จ"
                )
            }
        }
    }

    func chooseAndImportPackage() {
        let panel = NSOpenPanel()
        panel.title = "Import Image Pro Model Pack"
        panel.message = "Choose a .imagepromodel folder or a model-pack ZIP."
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importPackage(at: url)
    }

    func importPackage(at url: URL) {
        guard workingPackageID == nil else { return }
        workingPackageID = url.lastPathComponent
        statusText = "Importing \(url.lastPathComponent)…"
        Task {
            defer { workingPackageID = nil }
            do {
                let installed = try await Task.detached(priority: .userInitiated) { [store] in
                    try store.installPackage(at: url)
                }.value
                reloadInstalled()
                statusText = "Installed \(installed.manifest.displayName) \(installed.manifest.version)."
            } catch {
                errorMessage = error.localizedDescription
                statusText = "Model import failed."
            }
        }
    }

    func activate(_ model: InstalledModel, capability: ModelCapability) {
        do {
            try store.activate(
                modelID: model.manifest.id,
                version: model.manifest.version,
                for: capability
            )
            reloadInstalled()
            statusText = "\(model.manifest.displayName) is active for \(capability.displayName)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ model: InstalledModel) {
        guard workingPackageID == nil else { return }
        workingPackageID = model.id
        Task {
            defer { workingPackageID = nil }
            do {
                try await Task.detached(priority: .utility) { [store] in
                    try store.remove(modelID: model.manifest.id, version: model.manifest.version)
                }.value
                reloadInstalled()
                statusText = "Removed \(model.manifest.displayName)."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func revealModelsFolder() {
        try? FileManager.default.createDirectory(at: store.rootURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(store.rootURL)
    }

    func isInstalled(_ item: ModelCatalogItem) -> Bool {
        installedModels.contains {
            $0.manifest.id == item.package.id && $0.manifest.version == item.package.version
        }
    }

    func hasActiveModel(for capability: ModelCapability, engines: Set<ModelEngine>) -> Bool {
        installedModels.contains {
            $0.activeCapabilities.contains(capability) && engines.contains($0.manifest.engine)
        }
    }

    private func loadBundledCatalog() {
        guard
            let url = Bundle.main.url(forResource: "ModelCatalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(ModelCatalog.self, from: data)
        else { return }
        catalogPackages = catalog.packages
    }

    private var cachedCatalogURL: URL {
        store.rootURL.appendingPathComponent("catalog-cache.json", isDirectory: false)
    }

    private func loadCachedCatalog() {
        guard
            let data = try? Data(contentsOf: cachedCatalogURL),
            let catalog = try? JSONDecoder().decode(ModelCatalog.self, from: data),
            catalog.schemaVersion == 1
        else { return }
        catalogPackages = catalog.packages
    }

    private func cacheCatalog(_ data: Data) throws {
        try FileManager.default.createDirectory(at: store.rootURL, withIntermediateDirectories: true)
        try data.write(to: cachedCatalogURL, options: .atomic)
    }

    private func persistDownloadedArchive(at temporaryURL: URL) throws -> URL {
        let downloads = store.rootURL.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let destination = downloads
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("zip")
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        } catch {
            // Moving can fail if the URLSession temporary directory is on another
            // volume. A copy still gives us ownership beyond CFNetwork's lifetime.
            try FileManager.default.copyItem(at: temporaryURL, to: destination)
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        return destination
    }

    private func catalogFailureMessage(for error: Error) -> String {
        if case ModelNetworkError.httpStatus(404, .catalog) = error {
            return Self.localized(
                english: "The online catalog has not been published yet. Use Import Model Pack in the meantime.",
                thai: "ยังไม่ได้เผยแพร่รายการโมเดลออนไลน์ ระหว่างนี้ใช้ปุ่มนำเข้าแพ็กโมเดลได้"
            )
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return Self.localized(
                    english: "Could not reach the catalog. Cached and installed models remain available offline.",
                    thai: "ติดต่อรายการโมเดลไม่ได้ แต่รายการที่แคชและโมเดลที่ติดตั้งแล้วยังใช้ออฟไลน์ได้"
                )
            default:
                break
            }
        }
        return Self.localized(
            english: "The online catalog could not be read. Cached and installed models remain available.",
            thai: "อ่านรายการโมเดลออนไลน์ไม่ได้ แต่รายการที่แคชและโมเดลที่ติดตั้งแล้วยังใช้ได้"
        )
    }

    private func modelDownloadFailureMessage(for error: Error) -> String {
        if case let ModelNetworkError.httpStatus(status, .modelPack) = error {
            return Self.localized(
                english: "The model pack server returned HTTP \(status). The catalog may be out of date.",
                thai: "เซิร์ฟเวอร์โมเดลตอบกลับ HTTP \(status) รายการโมเดลอาจล้าสมัย"
            )
        }
        if let urlError = error as? URLError {
            return Self.localized(
                english: "Could not download the model pack (\(urlError.code.rawValue)). Check your connection and try again.",
                thai: "ดาวน์โหลดแพ็กโมเดลไม่ได้ (\(urlError.code.rawValue)) กรุณาตรวจอินเทอร์เน็ตแล้วลองใหม่"
            )
        }
        return error.localizedDescription
    }

    private nonisolated static func validate(
        response: URLResponse,
        resource: ModelNetworkResource
    ) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ModelNetworkError.invalidResponse(resource)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ModelNetworkError.httpStatus(http.statusCode, resource)
        }
    }

    private nonisolated static func localized(english: String, thai: String) -> String {
        UserDefaults.standard.string(forKey: AppLanguage.storageKey) == AppLanguage.thai.rawValue
            ? thai
            : english
    }
}

private enum ModelNetworkResource: Sendable {
    case catalog
    case modelPack
}

private enum ModelNetworkError: Error, Sendable {
    case httpStatus(Int, ModelNetworkResource)
    case invalidResponse(ModelNetworkResource)
}

extension ModelCapability {
    var displayName: String {
        switch self {
        case .erase: String(localized: "Erase")
        case .generate: String(localized: "Generate")
        case .ocr: String(localized: "OCR")
        case .segmentation: String(localized: "Segmentation")
        case .upscale: String(localized: "Upscale")
        }
    }
}
