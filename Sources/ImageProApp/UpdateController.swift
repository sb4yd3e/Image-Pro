import AppKit
import CryptoKit
import Foundation

struct GitHubRelease: Codable, Sendable {
    struct Asset: Codable, Sendable {
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name, size
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case name, body, draft, prerelease, assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

@MainActor
final class UpdateController: ObservableObject {
    static let automaticCheckKey = "imagePro.automaticallyChecksForUpdates"

    @Published private(set) var availableRelease: GitHubRelease?
    @Published private(set) var isChecking = false
    @Published private(set) var isInstalling = false
    @Published private(set) var statusText = UpdateController.localized(
        english: "Updates are delivered from GitHub Releases.",
        thai: "อัปเดตส่งผ่าน GitHub Releases"
    )
    @Published var errorMessage: String?

    private let repository = "sb4yd3e/Image-Pro"
    private let lastCheckKey = "imagePro.lastUpdateCheck"

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    func checkForUpdates(userInitiated: Bool = true) {
        guard !isChecking, !isInstalling else { return }
        isChecking = true
        if userInitiated {
            statusText = Self.localized(
                english: "Checking GitHub Releases…",
                thai: "กำลังตรวจ GitHub Releases…"
            )
        }
        Task {
            do {
                let release = try await fetchLatestRelease()
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
                if Self.isVersion(release.tagName, newerThan: currentVersion) {
                    availableRelease = release
                    statusText = Self.localized(
                        english: "Version \(Self.normalizedVersion(release.tagName)) is available.",
                        thai: "มีเวอร์ชัน \(Self.normalizedVersion(release.tagName)) พร้อมอัปเดต"
                    )
                } else {
                    availableRelease = nil
                    if userInitiated {
                        statusText = Self.localized(
                            english: "Image Pro is up to date.",
                            thai: "Image Pro เป็นเวอร์ชันล่าสุดแล้ว"
                        )
                    }
                }
            } catch {
                if userInitiated {
                    errorMessage = Self.localized(
                        english: "Could not check for updates: \(error.localizedDescription)",
                        thai: "ไม่สามารถตรวจหาอัปเดตได้: \(error.localizedDescription)"
                    )
                }
                statusText = Self.localized(
                    english: "Update check unavailable.",
                    thai: "ยังตรวจหาอัปเดตไม่ได้"
                )
            }
            isChecking = false
        }
    }

    func checkAutomaticallyIfNeeded() {
        guard UserDefaults.standard.object(forKey: Self.automaticCheckKey) as? Bool ?? true else { return }
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastCheck) > 24 * 60 * 60 else { return }
        checkForUpdates(userInitiated: false)
    }

    func installAvailableUpdate() {
        guard let release = availableRelease, !isInstalling else { return }
        isInstalling = true
        statusText = Self.localized(
            english: "Downloading \(Self.normalizedVersion(release.tagName))…",
            thai: "กำลังดาวน์โหลด \(Self.normalizedVersion(release.tagName))…"
        )
        Task {
            do {
                let preparedApp = try await downloadAndVerify(release)
                statusText = Self.localized(
                    english: "Installing update…",
                    thai: "กำลังติดตั้งอัปเดต…"
                )
                try launchInstaller(for: preparedApp)
            } catch {
                errorMessage = Self.localized(
                    english: "Could not install update: \(error.localizedDescription)",
                    thai: "ไม่สามารถติดตั้งอัปเดตได้: \(error.localizedDescription)"
                )
                statusText = Self.localized(
                    english: "Update installation failed.",
                    thai: "ติดตั้งอัปเดตไม่สำเร็จ"
                )
                isInstalling = false
            }
        }
    }

    func openReleasePage() {
        guard let url = availableRelease?.htmlURL else {
            NSWorkspace.shared.open(URL(string: "https://github.com/\(repository)/releases")!)
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Image-Pro-Updater/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.releaseUnavailable
        }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !release.draft, !release.prerelease else { throw UpdateError.releaseUnavailable }
        return release
    }

    private func downloadAndVerify(_ release: GitHubRelease) async throws -> URL {
        guard let archive = release.assets.first(where: {
            $0.name.lowercased().hasSuffix(".zip") && $0.name.lowercased().contains("image-pro")
        }) ?? release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) else {
            throw UpdateError.archiveMissing
        }
        guard let checksum = release.assets.first(where: {
            $0.name == archive.name + ".sha256" || $0.name.lowercased() == "sha256sums"
        }) else {
            throw UpdateError.checksumMissing
        }

        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Image Pro/Updates", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let archiveURL = root.appendingPathComponent(archive.name)
        let extractURL = root.appendingPathComponent("prepared-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: archiveURL)
        try FileManager.default.createDirectory(at: extractURL, withIntermediateDirectories: true)

        let (temporaryArchive, archiveResponse) = try await URLSession.shared.download(from: archive.browserDownloadURL)
        guard (archiveResponse as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.downloadFailed }
        try FileManager.default.moveItem(at: temporaryArchive, to: archiveURL)
        let (checksumData, checksumResponse) = try await URLSession.shared.data(from: checksum.browserDownloadURL)
        guard (checksumResponse as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.downloadFailed }
        let checksumText = String(decoding: checksumData, as: UTF8.self)
        guard let expected = checksumText
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .first(where: { $0.count == 64 && $0.allSatisfy(\.isHexDigit) })?
            .lowercased()
        else { throw UpdateError.checksumInvalid }
        let currentVersion = currentVersion
        let bundleIdentifier = Bundle.main.bundleIdentifier
        return try await Task.detached(priority: .utility) {
            try Self.verifyAndExtract(
                archiveURL: archiveURL,
                expectedSHA256: expected,
                extractURL: extractURL,
                bundleIdentifier: bundleIdentifier,
                currentVersion: currentVersion
            )
        }.value
    }

    private func launchInstaller(for preparedApp: URL) throws {
        let target = Bundle.main.bundleURL
        guard target.pathExtension == "app" else { throw UpdateError.appInvalid }
        let parent = target.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            NSWorkspace.shared.activateFileViewerSelecting([preparedApp])
            throw UpdateError.installPermission
        }

        let scriptURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Image Pro/Updates/install-update.sh")
        let staging = target.appendingPathExtension("update")
        let backup = target.appendingPathExtension("previous")
        let script = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf \(Self.shellQuote(staging.path)) \(Self.shellQuote(backup.path))
        /usr/bin/ditto \(Self.shellQuote(preparedApp.path)) \(Self.shellQuote(staging.path)) || exit 1
        /usr/bin/codesign --verify --deep --strict \(Self.shellQuote(staging.path)) || exit 1
        /bin/mv \(Self.shellQuote(target.path)) \(Self.shellQuote(backup.path)) || exit 1
        /bin/mv \(Self.shellQuote(staging.path)) \(Self.shellQuote(target.path)) || { /bin/mv \(Self.shellQuote(backup.path)) \(Self.shellQuote(target.path)); exit 1; }
        /usr/bin/open \(Self.shellQuote(target.path))
        /bin/rm -rf \(Self.shellQuote(backup.path))
        /bin/rm -f \(Self.shellQuote(scriptURL.path))
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        try process.run()
        NSApp.terminate(nil)
    }

    private nonisolated static func runProcess(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.unpackFailed
        }
    }

    private nonisolated static func verifyAndExtract(
        archiveURL: URL,
        expectedSHA256: String,
        extractURL: URL,
        bundleIdentifier: String?,
        currentVersion: String
    ) throws -> URL {
        let data = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expectedSHA256 else { throw UpdateError.checksumInvalid }

        try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, extractURL.path])
        var preparedApp: URL?
        if let enumerator = FileManager.default.enumerator(
            at: extractURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            while let candidate = enumerator.nextObject() as? URL {
                if candidate.pathExtension == "app", candidate.lastPathComponent == "Image Pro.app" {
                    preparedApp = candidate
                    enumerator.skipDescendants()
                    break
                }
            }
        }
        guard let app = preparedApp,
              let bundle = Bundle(url: app),
              bundle.bundleIdentifier == bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              isVersion(version, newerThan: currentVersion)
        else { throw UpdateError.appInvalid }
        return app
    }

    private nonisolated static func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        normalizedVersion(candidate).compare(
            normalizedVersion(current),
            options: .numeric
        ) == .orderedDescending
    }

    private nonisolated static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private nonisolated static func localized(english: String, thai: String) -> String {
        UserDefaults.standard.string(forKey: AppLanguage.storageKey) == AppLanguage.thai.rawValue
            ? thai
            : english
    }
}

private enum UpdateError: LocalizedError {
    case releaseUnavailable, archiveMissing, checksumMissing, checksumInvalid
    case downloadFailed, unpackFailed, appInvalid, installPermission

    var errorDescription: String? {
        switch self {
        case .releaseUnavailable: "GitHub has no usable stable release."
        case .archiveMissing: "The release has no Image Pro ZIP archive."
        case .checksumMissing: "The release has no SHA-256 checksum asset, so it was not trusted."
        case .checksumInvalid: "The downloaded archive failed SHA-256 verification."
        case .downloadFailed: "The release download failed."
        case .unpackFailed: "The update archive could not be unpacked."
        case .appInvalid: "The archive does not contain a valid newer Image Pro app."
        case .installPermission: "Image Pro cannot replace itself here. The downloaded app was revealed in Finder."
        }
    }
}
