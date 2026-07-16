import Foundation

public enum OutputURLResolver {
    public static func resolve(
        _ desired: URL,
        policy: OutputCollisionPolicy,
        fileManager: FileManager = .default
    ) -> URL? {
        guard fileManager.fileExists(atPath: desired.path) else { return desired }
        switch policy {
        case .replace:
            return desired
        case .skip:
            return nil
        case .uniqueName:
            let directory = desired.deletingLastPathComponent()
            let stem = desired.deletingPathExtension().lastPathComponent
            let ext = desired.pathExtension
            for number in 2...9_999 {
                let candidate = directory
                    .appendingPathComponent("\(stem)-\(number)")
                    .appendingPathExtension(ext)
                if !fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
            return nil
        }
    }
}
