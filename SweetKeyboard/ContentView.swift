import Combine
import SwiftUI

@MainActor
final class AppScreenModel: ObservableObject {
    @Published private(set) var sharedSettings = SharedKeyboardSettings()
    @Published private(set) var capabilityStatus = KeyboardCapabilityStatus()

    private let sharedSettingsStore = SharedKeyboardSettingsStore()
    private let capabilityStatusStore = KeyboardCapabilityStatusStore()

    var canEnableClipboardMode: Bool {
        hasConfirmedFullAccess
    }

    var hasConfirmedFullAccess: Bool {
        capabilityStatus.lastConfirmedFullAccessAt != nil
    }

    var fullAccessHistorySummary: String {
        KeyboardCapabilityStatusTextFormatter.historySummary(for: capabilityStatus)
    }

    var fullAccessSettingsSummary: String {
        KeyboardCapabilityStatusTextFormatter.appSettingsSummary(for: capabilityStatus)
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
        sharedSettings = sharedSettingsStore.load()
        capabilityStatus = capabilityStatusStore.load()
    }

    func setAutoCapitalizationEnabled(_ isEnabled: Bool) {
        sharedSettings.autoCapitalizationEnabled = isEnabled
        sharedSettingsStore.setAutoCapitalizationEnabled(isEnabled)
    }

    func setClipboardModeEnabled(_ isEnabled: Bool) {
        sharedSettings.clipboardModeEnabled = isEnabled
        sharedSettingsStore.setClipboardModeEnabled(isEnabled)
    }

    func setKeyHapticsEnabled(_ isEnabled: Bool) {
        sharedSettings.keyHapticsEnabled = isEnabled
        sharedSettingsStore.setKeyHapticsEnabled(isEnabled)
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppScreenModel()

    var body: some View {
        TabView {
            tabContainer {
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

            tabContainer(title: "Features") {
                FeaturesView()
            }
            .tabItem {
                Label("Features", systemImage: "sparkles")
            }

            tabContainer(title: "Info") {
                InfoView()
            }
            .tabItem {
                Label("Info", systemImage: "info.circle")
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
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            AppScreen(content: content)
                .modifier(NavigationChromeModifier(title: title))
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var model: AppScreenModel

    var body: some View {
        VStack(spacing: 18) {
            AppHeroCard(
                title: "Install the keyboard in a few steps"
            )

            InstallStepCard(
                number: "1",
                title: "Add SweetKeyboard",
                message: "Open Settings, then go to General > Keyboard > Keyboards > Add New Keyboard and choose SweetKeyboard."
            )

            InstallStepCard(
                number: "2",
                title: "Turn on Full Access only if you want clipboard tools.",
                message: "In Keyboards settings, tap on SweetKeyboard. Turn on Full Access and tap Allow.",
                showsFilledNumber: false
            ) {
                CapabilityBadge(
                    title: model.fullAccessHistorySummary,
                    color: AppTheme.accent
                )
            }

            InstallStepCard(
                number: "3",
                title: "Open the keyboard",
                message: "Tap the globe button in any text field, then switch to SweetKeyboard."
            )

            InstallStepCard(
                number: "4",
                title: "Come back to review settings",
                message: "Your keyboard options are then available here and inside the keyboard itself.",
                showsFilledNumber: false
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
                title: "Clipboard toolbar",
                message: "Shows Copy, Paste, Clipboard, and Settings above the keyboard.",
                isOn: Binding(
                    get: { model.sharedSettings.clipboardModeEnabled },
                    set: model.setClipboardModeEnabled
                ),
                footnote: model.fullAccessSettingsSummary
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
                    model.fullAccessHistorySummary,
                    "Clipboard tools appear only when the keyboard currently has Full Access."
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

private struct FeaturesView: View {
    @EnvironmentObject private var model: AppScreenModel

    private let typingBasicsItems = [
        FeatureItem(
            title: "QWERTY layout",
            message: "Type on a familiar English keyboard layout."
        ),
        FeatureItem(
            title: "Number row",
            message: "Numbers stay visible at the top, so you do not need to switch layouts for basic digits."
        ),
        FeatureItem(
            title: "Period key",
            message: "A period is always available in letter mode for faster everyday typing."
        ),
        FeatureItem(
            title: "Action key",
            message: "The return key adapts to the current field when iOS provides the right context."
        ),
        FeatureItem(
            title: "Email shortcut",
            message: "Email fields can show a dedicated @ key to make addresses faster to enter."
        )
    ]

    private let smartTypingItems = [
        FeatureItem(
            title: "Auto-capitalization",
            message: "Shift turns on automatically at the start of sentences and after supported punctuation."
        ),
        FeatureItem(
            title: "Manual Shift",
            message: "Tap Shift once for one capital letter, or tap twice to lock capitals."
        ),
        FeatureItem(
            title: "Smart override",
            message: "If automatic Shift is active, tapping Shift lets you take over manually for the current context."
        ),
        FeatureItem(
            title: "Fast typing support",
            message: "Overlapping touches are handled in press order to reduce missed keys when typing quickly."
        ),
        FeatureItem(
            title: "Field-aware behavior",
            message: "Auto-capitalization stays off in email, URL, and similar input fields."
        )
    ]

    private let symbolsAndEmojiItems = [
        FeatureItem(
            title: "Symbols layout",
            message: "A dedicated symbols keyboard gives quick access to punctuation and special characters."
        ),
        FeatureItem(
            title: "Emoji layout",
            message: "You can open a built-in emoji view directly from symbols mode."
        ),
        FeatureItem(
            title: "Cursor controls",
            message: "Left and right arrow keys help move the cursor while staying in non-letter layouts."
        ),
        FeatureItem(
            title: "Auto return",
            message: "After entering a single symbol or emoji, the keyboard can jump back to letters for faster typing."
        ),
        FeatureItem(
            title: "Symbol lock",
            message: "Turn on symbol lock to stay in symbols or emoji mode for repeated entry."
        ),
        FeatureItem(
            title: "Inline settings key",
            message: "Compact non-letter layouts can show a settings shortcut directly inside the keyboard."
        )
    ]

    private let holdForMoreItems = [
        FeatureItem(
            title: "Accent variants",
            message: "Supported letters can open accented and alternate versions with a long press."
        ),
        FeatureItem(
            title: "Uppercase variants",
            message: "When Shift is active, long-press variants follow the same uppercase behavior."
        ),
        FeatureItem(
            title: "Period shortcuts",
            message: "Holding the period key reveals extra punctuation shortcuts such as ellipsis and symbols."
        ),
        FeatureItem(
            title: "Temporary replacement",
            message: "The keyboard swaps in these alternate choices during the press, then returns to normal afterward."
        )
    ]

    private let clipboardToolsItems = [
        FeatureItem(
            title: "Copy",
            message: "Copies selected text when the current app exposes it to the keyboard."
        ),
        FeatureItem(
            title: "Paste",
            message: "Pastes the current system clipboard contents into the active field."
        ),
        FeatureItem(
            title: "Clipboard history",
            message: "Saved snippets are listed locally so you can paste recent items again quickly."
        ),
        FeatureItem(
            title: "Toolbar shortcut",
            message: "The top bar can also open keyboard settings directly."
        )
    ]

    private let sharedSettingsItems = [
        FeatureItem(
            title: "Clipboard toolbar",
            message: "Turn the top clipboard bar on or off from the app or from the keyboard."
        ),
        FeatureItem(
            title: "Auto-capitalization",
            message: "Choose whether Shift should react automatically to sentence context."
        ),
        FeatureItem(
            title: "Key haptics",
            message: "Enable light tactile feedback on supported devices and actions."
        ),
        FeatureItem(
            title: "Shared state",
            message: "Changes made in the app are reflected inside the keyboard automatically."
        )
    ]

    private let highlightItems = [
        "Always-on numbers",
        "Smart Shift",
        "Symbols & emoji",
        "Clipboard tools"
    ]

    var body: some View {
        VStack(spacing: 18) {
            AppHeroCard(
                eyebrow: "Features",
                title: "Everything SweetKeyboard can do",
                message: "A quick guide to typing, symbols, shortcuts, and smart behavior built into the keyboard."
            ) {
                FeatureHighlightsCard(items: highlightItems)
            }

            FeatureSectionCard(
                title: "Typing Basics",
                systemImage: "keyboard",
                intro: "The default layout keeps the most-used keys visible and predictable.",
                items: typingBasicsItems
            )

            FeatureSectionCard(
                title: "Smart Typing",
                systemImage: "shift",
                intro: "SweetKeyboard helps with capitalization and keeps up with fast input.",
                items: smartTypingItems
            )

            FeatureSectionCard(
                title: "Symbols & Emoji",
                systemImage: "face.smiling",
                intro: "Extra characters stay close when you need them, without slowing normal typing.",
                items: symbolsAndEmojiItems
            )

            FeatureSectionCard(
                title: "Hold For More",
                systemImage: "ellipsis.circle",
                intro: "Some keys reveal extra characters when you press and hold them.",
                items: holdForMoreItems
            ) {
                EmptyView()
            }

            FeatureSectionCard(
                title: "Clipboard Tools",
                systemImage: "doc.on.clipboard",
                intro: "Optional clipboard actions live above the keyboard when Full Access is available.",
                items: clipboardToolsItems
            ) {
                CapabilityBadge(
                    title: model.canEnableClipboardMode
                        ? "Full Access is enabled"
                        : "Full Access is required for clipboard tools",
                    systemImage: model.canEnableClipboardMode
                        ? "checkmark.circle.fill"
                        : "exclamationmark.circle.fill",
                    color: model.canEnableClipboardMode ? AppTheme.success : AppTheme.accent
                )
            }

            FeatureSectionCard(
                title: "Shared Settings",
                systemImage: "switch.2",
                intro: "The app and the keyboard stay in sync for the main behavior toggles.",
                items: sharedSettingsItems
            )
        }
    }
}

private struct NavigationChromeModifier: ViewModifier {
    let title: String?

    func body(content: Content) -> some View {
        if let title {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
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
    let eyebrow: String?
    let title: String
    let message: String?
    @ViewBuilder var accessory: Accessory

    init(
        eyebrow: String? = nil,
        title: String,
        message: String? = nil,
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
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.accent)
                }

                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)

                if let message {
                    Text(message)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                accessory
            }
        }
    }
}

private struct InstallStepCard<Accessory: View>: View {
    let number: String
    let title: String
    let message: String
    let showsFilledNumber: Bool
    @ViewBuilder var accessory: Accessory

    init(
        number: String,
        title: String,
        message: String,
        showsFilledNumber: Bool = true,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.number = number
        self.title = title
        self.message = message
        self.showsFilledNumber = showsFilledNumber
        self.accessory = accessory()
    }

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 14) {
                stepNumber

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

    private var stepNumber: some View {
        Text(number)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(showsFilledNumber ? .white : AppTheme.accent)
            .frame(width: 34, height: 34)
            .background {
                if showsFilledNumber {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accent)
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

private struct FeatureItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct FeatureSectionCard<Accessory: View>: View {
    let title: String
    let systemImage: String
    let intro: String
    let items: [FeatureItem]
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        systemImage: String,
        intro: String,
        items: [FeatureItem],
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.intro = intro
        self.items = items
        self.accessory = accessory()
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.12))
                        )

                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                Text(intro)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        FeatureItemRow(item: item)
                    }
                }

                accessory
            }
        }
    }
}

private struct FeatureItemRow: View {
    let item: FeatureItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(item.message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
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

private struct FeatureHighlightsCard: View {
    let items: [String]
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.10))
                        )
                }
            }
        }
    }
}

private struct CapabilityBadge: View {
    let title: String
    var systemImage: String? = nil
    let color: Color

    var body: some View {
        Group {
            if let systemImage {
                Label {
                    Text(title)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                } icon: {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
            } else {
                Text(title)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
            }
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.10))
        )
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
