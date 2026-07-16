import ImageProCore
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

enum AppSettingsTab: Hashable {
    case general
    case models
}

@MainActor
final class SettingsNavigationController: ObservableObject {
    @Published var selectedTab: AppSettingsTab = .general

    func showModels() {
        selectedTab = .models
    }

    func showGeneral() {
        selectedTab = .general
    }
}

struct AppSettingsView: View {
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var modelManager: ModelManagerController
    @EnvironmentObject private var navigation: SettingsNavigationController
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.english.rawValue
    @AppStorage(UpdateController.automaticCheckKey) private var automaticallyChecksForUpdates = true

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .english
    }

    private var contentHeight: CGFloat {
        switch navigation.selectedTab {
        case .general:
            return 330
        case .models:
            let installedExtra = modelManager.installedModels.isEmpty
                ? CGFloat(24)
                : CGFloat(max(0, min(modelManager.installedModels.count, 3) - 1)) * 66
            let catalogExtra = modelManager.catalogPackages.isEmpty
                ? CGFloat(0)
                : CGFloat(28 + max(0, min(modelManager.catalogPackages.count, 2) - 1) * 66)
            return min(370 + installedExtra + catalogExtra, 560)
        }
    }

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            GeneralSettingsView()
                .environmentObject(updateController)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(AppSettingsTab.general)
            ModelManagerView()
                .environmentObject(modelManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem { Label("Models", systemImage: "shippingbox") }
                .tag(AppSettingsTab.models)
        }
        .frame(width: 650, height: contentHeight, alignment: .topLeading)
        .environment(\.locale, language.locale)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var updateController: UpdateController
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.english.rawValue
    @AppStorage(UpdateController.automaticCheckKey) private var automaticallyChecksForUpdates = true

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
        .padding(20)
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

private struct ModelManagerView: View {
    @EnvironmentObject private var controller: ModelManagerController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI Models").font(.title2.bold())
                    Text("Install only the models you use. The app remains small and works offline after installation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Import Model Pack…", systemImage: "square.and.arrow.down") {
                    controller.chooseAndImportPackage()
                }
                .buttonStyle(.borderedProminent)
                Button("Check Catalog", systemImage: "arrow.clockwise") {
                    controller.refreshCatalog()
                }
                .disabled(controller.isRefreshing || controller.workingPackageID != nil)
                Button("Open Models Folder", systemImage: "folder") {
                    controller.revealModelsFolder()
                }
                Spacer()
                if controller.isRefreshing || controller.workingPackageID != nil {
                    ProgressView().controlSize(.small)
                }
            }

            Text(controller.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            GroupBox("Installed") {
                if controller.installedModels.isEmpty {
                    ContentUnavailableView(
                        "No Models Installed",
                        systemImage: "shippingbox",
                        description: Text("Import a model pack or download one from the catalog.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 90)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(controller.installedModels) { model in
                                InstalledModelRow(model: model)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: installedListHeight)
                }
            }

            GroupBox("Available to Download") {
                if controller.catalogPackages.isEmpty {
                    Text("No remote packs are listed in the current catalog. Local model packs can still be imported.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(controller.catalogPackages) { item in
                                CatalogModelRow(item: item)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: catalogListHeight)
                }
            }
        }
        .padding(20)
        .alert("Image Pro", isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(controller.errorMessage ?? "Unknown error")
        }
    }

    private var installedListHeight: CGFloat {
        min(CGFloat(controller.installedModels.count) * 66, 198)
    }

    private var catalogListHeight: CGFloat {
        min(CGFloat(controller.catalogPackages.count) * 66, 132)
    }
}

private struct InstalledModelRow: View {
    @EnvironmentObject private var controller: ModelManagerController
    let model: InstalledModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .frame(width: 32, height: 32)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.manifest.displayName).font(.callout.weight(.semibold))
                    Text(model.manifest.version).font(.caption2).foregroundStyle(.secondary)
                }
                Text(model.manifest.capabilities.map(\.displayName).joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ForEach(model.manifest.capabilities, id: \.self) { capability in
                Button(model.activeCapabilities.contains(capability) ? "Active" : "Use for \(capability.displayName)") {
                    controller.activate(model, capability: capability)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.activeCapabilities.contains(capability))
            }
            Button(role: .destructive) { controller.remove(model) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(controller.workingPackageID != nil)
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct CatalogModelRow: View {
    @EnvironmentObject private var controller: ModelManagerController
    let item: ModelCatalogItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.package.displayName).font(.callout.weight(.semibold))
                Text("\(item.package.capabilities.map(\.displayName).joined(separator: " • ")) · \(ByteCountFormatter.string(fromByteCount: item.archiveBytes, countStyle: .file)) · \(item.package.license)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(controller.isInstalled(item) ? "Installed" : "Download") {
                controller.install(item)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(controller.isInstalled(item) || controller.workingPackageID != nil)
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }
}
