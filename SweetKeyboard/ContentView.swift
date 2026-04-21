import Combine
import SwiftUI

@MainActor
final class AppScreenModel: ObservableObject {
    @Published private(set) var history: [ClipboardItem] = []
    @Published private(set) var actionSnapshots: [ActionKeyDebugSnapshot] = []
    @Published private(set) var sharedSettings = SharedKeyboardSettings()
    @Published private(set) var capabilityStatus = KeyboardCapabilityStatus()

    private let clipboardStore = ClipboardStore()
    private let actionKeyDebugStore = ActionKeyDebugStore()
    private let sharedSettingsStore = SharedKeyboardSettingsStore()
    private let capabilityStatusStore = KeyboardCapabilityStatusStore()

    var canEnableClipboardMode: Bool {
        capabilityStatus.lastConfirmedFullAccessAt != nil
    }

    var versionDescription: String? {
        guard let info = Bundle.main.infoDictionary else {
            return nil
        }

        let version = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        default:
            return nil
        }
    }

    func reload() {
        history = clipboardStore.allItems()
        actionSnapshots = actionKeyDebugStore.allSnapshots()
        sharedSettings = sharedSettingsStore.load()
        capabilityStatus = capabilityStatusStore.load()
    }

    func setAutoCapitalizationEnabled(_ isEnabled: Bool) {
        sharedSettings.autoCapitalizationEnabled = isEnabled
        sharedSettingsStore.setAutoCapitalizationEnabled(isEnabled)
    }

    func setClipboardModeEnabled(_ isEnabled: Bool) {
        guard canEnableClipboardMode || !isEnabled else {
            return
        }

        sharedSettings.clipboardModeEnabled = isEnabled
        sharedSettingsStore.setClipboardModeEnabled(isEnabled)
    }

    func setKeyHapticsEnabled(_ isEnabled: Bool) {
        sharedSettings.keyHapticsEnabled = isEnabled
        sharedSettingsStore.setKeyHapticsEnabled(isEnabled)
    }

    func addClipboardItem(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        clipboardStore.add(text: trimmed, source: .manualImport)
        history = clipboardStore.allItems()
    }

    func clearClipboardHistory() {
        clipboardStore.clearAll()
        history = []
    }

    func clearActionSnapshots() {
        actionKeyDebugStore.clearAll()
        actionSnapshots = []
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppScreenModel()

    var body: some View {
        TabView {
            tabContainer(title: "SweetKeyboard") {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            tabContainer(title: "Settings") {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "switch.2")
            }

            tabContainer(title: "Info") {
                InfoView()
            }
            .tabItem {
                Label("Info", systemImage: "info.circle")
            }

            tabContainer(title: "Debug") {
                DebugView()
            }
            .tabItem {
                Label("Debug", systemImage: "waveform.path.ecg")
            }
        }
        .tint(AppTheme.accent)
        .environmentObject(model)
        .task {
            model.reload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            model.reload()
        }
    }

    private func tabContainer<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            AppScreen(content: content)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var model: AppScreenModel

    var body: some View {
        VStack(spacing: 18) {
            AppHeroCard(
                eyebrow: "SweetKeyboard",
                title: "Install the keyboard in a few steps",
                message: "The keyboard works right away for typing. Turn on Full Access only if you want clipboard tools."
            )

            InstallStepCard(
                number: "1",
                title: "Add SweetKeyboard",
                message: "Open Settings, then go to General > Keyboard > Keyboards > Add New Keyboard and choose SweetKeyboard."
            )

            InstallStepCard(
                number: "2",
                title: "Open the keyboard",
                message: "Tap the globe button in any text field, then switch to SweetKeyboard."
            )

            InstallStepCard(
                number: "3",
                title: "Enable Full Access if needed",
                message: "Only if needed: open the globe menu, tap Keyboard Settings, then go to Keyboard > SweetKeyboard. Turn on Full Access and tap Allow."
            ) {
                if !model.canEnableClipboardMode {
                    CapabilityBadge(
                        title: "Full Access Required for Clipboard",
                        systemImage: "exclamationmark.circle.fill",
                        color: AppTheme.accent
                    )
                }
            }

            InstallStepCard(
                number: "4",
                title: "Come back to review settings",
                message: "Your keyboard options are then available here and inside the keyboard itself."
            )
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppScreenModel

    var body: some View {
        VStack(spacing: 18) {
            AppHeroCard(
                eyebrow: "Settings",
                title: "The essentials, nothing more",
                message: "Each setting is shared automatically between the app and the keyboard."
            )

            SettingsToggleCard(
                title: "Auto-capitalization",
                message: "Automatically enables Shift at the start of sentences and in compatible fields.",
                isOn: Binding(
                    get: { model.sharedSettings.autoCapitalizationEnabled },
                    set: model.setAutoCapitalizationEnabled
                )
            )

            SettingsToggleCard(
                title: "Clipboard toolbar",
                message: "Shows Copy, Paste, Clipboard, and Settings above the keyboard.",
                isOn: Binding(
                    get: { model.sharedSettings.clipboardModeEnabled },
                    set: model.setClipboardModeEnabled
                ),
                isDisabled: !model.canEnableClipboardMode && !model.sharedSettings.clipboardModeEnabled,
                footnote: model.canEnableClipboardMode
                    ? nil
                    : "Tap Keyboard, SweetKeyboard, turn on Full Access, tap Allow, then reopen the keyboard."
            )

            SettingsToggleCard(
                title: "Key haptics",
                message: "Adds light haptic feedback to supported keys and actions.",
                isOn: Binding(
                    get: { model.sharedSettings.keyHapticsEnabled },
                    set: model.setKeyHapticsEnabled
                )
            )
        }
    }
}

private struct InfoView: View {
    @EnvironmentObject private var model: AppScreenModel

    var body: some View {
        VStack(spacing: 18) {
            AppHeroCard(
                eyebrow: "Info",
                title: "Simple, local, and predictable",
                message: "SweetKeyboard stays intentionally compact and relies only on the iOS capabilities that are available."
            )

            InfoCard(
                title: "Privacy",
                items: [
                    "Clipboard data stays on this device.",
                    "No network, no analytics, no cloud."
                ]
            )

            InfoCard(
                title: "Full Access",
                items: [
                    "Required only for clipboard tools and for sharing certain states between the app and the extension.",
                    model.canEnableClipboardMode
                        ? "The keyboard has already confirmed Full Access on this device."
                        : "Without Full Access, SweetKeyboard stays in basic typing mode."
                ]
            )

            InfoCard(
                title: "iOS Limits",
                items: [
                    "Third-party keyboards are unavailable in some secure fields.",
                    "Some apps limit or completely block custom keyboards.",
                    "The Copy action depends on text exposed by the host app."
                ]
            )

            if let versionDescription = model.versionDescription {
                InfoCard(
                    title: "About",
                    items: [
                        "SweetKeyboard",
                        versionDescription
                    ]
                )
            }
        }
    }
}

private struct DebugView: View {
    @EnvironmentObject private var model: AppScreenModel
    @State private var manualClipboardText = ""

    var body: some View {
        VStack(spacing: 18) {
            AppHeroCard(
                eyebrow: "Debug",
                title: "Technical tools separated from the main experience",
                message: "These views are for checking local clipboard behavior and the action key behavior."
            )

            AppCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Clipboard Debug", subtitle: "Local history used by the clipboard bar.")

                    TextField("Manual import text", text: $manualClipboardText)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack(spacing: 10) {
                        Button("Add to Local History") {
                            let trimmed = manualClipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else {
                                return
                            }

                            model.addClipboardItem(text: trimmed)
                            manualClipboardText = ""
                        }
                        .buttonStyle(FilledActionButtonStyle())

                        Button("Clear History", role: .destructive) {
                            model.clearClipboardHistory()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    if model.history.isEmpty {
                        EmptyStateLabel("No local clipboard items yet.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(model.history) { item in
                                DebugItemRow(
                                    title: item.text,
                                    detail: item.createdAt.formatted(date: .abbreviated, time: .shortened)
                                )
                            }
                        }
                    }
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        title: "Action Key Debug",
                        subtitle: "Trait snapshots recorded by the extension, without typed text."
                    )

                    Button("Clear Action Key Log", role: .destructive) {
                        model.clearActionSnapshots()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    if model.actionSnapshots.isEmpty {
                        EmptyStateLabel("No action-key observations yet.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(model.actionSnapshots) { snapshot in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(snapshot.accessibilityLabel) · \(snapshot.displayMode)")
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(AppTheme.primaryText)

                                    Text(snapshot.debugDescription)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(AppTheme.secondaryText)

                                    Text(snapshotSummary(snapshot))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(AppTheme.secondaryText)

                                    Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.innerCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    private func snapshotSummary(_ snapshot: ActionKeyDebugSnapshot) -> String {
        let returnKey = snapshot.returnKeyType ?? "unavailable"
        let keyboardType = snapshot.keyboardType ?? "unavailable"
        let textContentType = snapshot.textContentType ?? "nil"
        let autoReturn = snapshot.enablesReturnKeyAutomatically.map(String.init) ?? "nil"

        return "returnKeyType=\(returnKey)  keyboardType=\(keyboardType)  textContentType=\(textContentType)  autoReturn=\(autoReturn)  hasText=\(snapshot.hasText)  hasDocumentText=\(snapshot.hasDocumentText)"
    }
}

private struct AppScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground().ignoresSafeArea())
    }
}

private struct AppHeroCard<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder var accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        message: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.accessory = accessory()
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(eyebrow.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.accent)

                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)

                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                accessory
            }
        }
    }
}

private struct InstallStepCard<Accessory: View>: View {
    let number: String
    let title: String
    let message: String
    @ViewBuilder var accessory: Accessory

    init(
        number: String,
        title: String,
        message: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.number = number
        self.title = title
        self.message = message
        self.accessory = accessory()
    }

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 14) {
                Text(number)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    accessory
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct SettingsToggleCard: View {
    let title: String
    let message: String
    let isOn: Binding<Bool>
    var isDisabled = false
    var footnote: String?

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: isOn) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(isDisabled ? AppTheme.tertiaryText : AppTheme.primaryText)
                }
                .tint(AppTheme.accent)
                .disabled(isDisabled)

                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let footnote {
                    Text(footnote)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct InfoCard: View {
    let title: String
    let items: [String]

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(AppTheme.accent)
                                .frame(width: 7, height: 7)
                                .padding(.top, 7)

                            Text(item)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct DebugItemRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)

            Text(detail)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.innerCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            Text(subtitle)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyStateLabel: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.innerCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CapabilityBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: Capsule())
    }
}

private struct AppCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 24, y: 10)
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, AppTheme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppTheme.accent.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 18)
                .offset(x: 120, y: -260)

            Circle()
                .fill(AppTheme.success.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 10)
                .offset(x: -130, y: -120)
        }
    }
}

private struct FilledActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.accent.opacity(0.78) : AppTheme.accent)
            )
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.innerCardBackground.opacity(0.75) : AppTheme.innerCardBackground)
            )
    }
}

private enum AppTheme {
    static let background = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let cardBackground = Color.white.opacity(0.88)
    static let innerCardBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let fieldBackground = Color.white.opacity(0.96)
    static let accent = Color(red: 0.96, green: 0.43, blue: 0.29)
    static let success = Color(red: 0.20, green: 0.61, blue: 0.42)
    static let primaryText = Color(red: 0.10, green: 0.15, blue: 0.23)
    static let secondaryText = Color(red: 0.35, green: 0.40, blue: 0.49)
    static let tertiaryText = Color(red: 0.55, green: 0.60, blue: 0.68)
    static let cardBorder = Color.white.opacity(0.75)
    static let shadow = Color.black.opacity(0.08)
}

#Preview {
    ContentView()
}
