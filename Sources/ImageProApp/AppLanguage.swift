import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case thai = "th"

    static let storageKey = "imagePro.appLanguage"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var shortTitle: String {
        switch self {
        case .english: "EN"
        case .thai: "TH"
        }
    }
}

struct AppSettingsView: View {
    @EnvironmentObject private var updateController: UpdateController
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.english.rawValue
    @AppStorage(UpdateController.automaticCheckKey) private var automaticallyChecksForUpdates = true

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .english
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Language & Appearance")
                        .font(.title2.bold())
                    Text("Choose the language used throughout Image Pro.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                Picker("App Language", selection: $languageRawValue) {
                    Text("English").tag(AppLanguage.english.rawValue)
                    Text("Thai").tag(AppLanguage.thai.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("App Language")
            } label: {
                Label("App Language", systemImage: "character.bubble")
                    .font(.headline)
            }

            Text("The interface updates immediately. Your images and projects are not changed.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Automatically check once a day", isOn: $automaticallyChecksForUpdates)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current version \(updateController.currentVersion)")
                                .font(.callout.weight(.medium))
                            Text(updateController.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if updateController.isChecking || updateController.isInstalling {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button("Check Now") { updateController.checkForUpdates() }
                            .disabled(updateController.isChecking || updateController.isInstalling)
                    }
                    if updateController.availableRelease != nil {
                        HStack {
                            Button("View Release") { updateController.openReleasePage() }
                            Spacer()
                            Button("Download and Install") { updateController.installAvailableUpdate() }
                                .buttonStyle(.borderedProminent)
                                .disabled(updateController.isInstalling)
                        }
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Software Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                    .font(.headline)
            }
        }
        .padding(24)
        .frame(width: 500)
        .environment(\.locale, language.locale)
        .alert("Image Pro", isPresented: Binding(
            get: { updateController.errorMessage != nil },
            set: { if !$0 { updateController.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(updateController.errorMessage ?? "Unknown error")
        }
    }
}
