import Combine
import SwiftUI
import UIKit

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

    func setOpenClipboardAfterCopyEnabled(_ isEnabled: Bool) {
        sharedSettings.openClipboardAfterCopyEnabled = isEnabled
        sharedSettingsStore.setOpenClipboardAfterCopyEnabled(isEnabled)
    }

    func setKeyHapticsEnabled(_ isEnabled: Bool) {
        sharedSettings.keyHapticsEnabled = isEnabled
        sharedSettingsStore.setKeyHapticsEnabled(isEnabled)
    }

    func setCursorSwipeEnabled(_ isEnabled: Bool) {
        sharedSettings.cursorSwipeEnabled = isEnabled
        sharedSettingsStore.setCursorSwipeEnabled(isEnabled)
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
                Label("Features", systemImage: "keyboard")
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
                message: "Shows Copy, Import, Clipboard, and Settings above the keyboard.",
                isOn: Binding(
                    get: { model.sharedSettings.clipboardModeEnabled },
                    set: model.setClipboardModeEnabled
                ),
                footnote: model.fullAccessSettingsSummary
            )

            SettingsToggleCard(
                title: "Open clipboard after copy",
                message: "After a successful Copy action, automatically shows your local clipboard history.",
                isOn: Binding(
                    get: { model.sharedSettings.openClipboardAfterCopyEnabled },
                    set: model.setOpenClipboardAfterCopyEnabled
                )
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
                title: "Swipe cursor",
                message: "Swipe horizontally on the keyboard to move the cursor through text.",
                isOn: Binding(
                    get: { model.sharedSettings.cursorSwipeEnabled },
                    set: model.setCursorSwipeEnabled
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
                    "System clipboard import only reads plain text after you tap the import button.",
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

    private let essentialFeatures = [
        EssentialFeature(
            title: "Numbers stay visible",
            message: "The top row keeps 1 through 0 on the main letter keyboard, so dates, codes, addresses, and passwords take fewer switches.",
            systemImage: "keyboard",
            callout: "Main keyboard"
        ),
        EssentialFeature(
            title: "Symbols in one place",
            message: "SweetKeyboard keeps the native-style symbols together on a single symbols page, with punctuation close by when you need it.",
            systemImage: "command",
            callout: "One symbols page"
        ),
        EssentialFeature(
            title: "Cursor keys",
            message: "Dedicated left and right keys let you move through text precisely without fighting the magnifier.",
            systemImage: "arrow.left.and.right",
            callout: "Precise edits"
        ),
        EssentialFeature(
            title: "Swipe cursor movement",
            message: "Swipe horizontally anywhere across the keyboard to move the cursor. Faster swipes travel farther, making long edits quicker.",
            systemImage: "hand.draw",
            callout: "Speed-aware"
        ),
        EssentialFeature(
            title: "Clipboard history and favorites",
            message: "Keep copied text in local history, pin important snippets as favorites, and paste them back with one tap.",
            systemImage: "doc.on.clipboard",
            callout: "Full Access optional"
        )
    ]

    private let secondaryFeatures = [
        FeatureItem(
            title: "Auto-capitalization",
            message: "Shift reacts to sentence context, field type, and manual override."
        ),
        FeatureItem(
            title: "Contextual action key",
            message: "Return can become Search, Go, Next, Send, Done, and related host actions."
        ),
        FeatureItem(
            title: "Email @ shortcut",
            message: "Email fields can show a direct @ key on the letter keyboard."
        ),
        FeatureItem(
            title: "Emoji from symbols",
            message: "Emoji stay available from the symbols layer without crowding the main keyboard."
        ),
        FeatureItem(
            title: "Symbol lock",
            message: "Stay in symbols or emoji for repeated entry, or return to letters after one tap."
        ),
        FeatureItem(
            title: "Long-press extras",
            message: "Accent variants and period shortcuts appear only when you hold supported keys."
        ),
        FeatureItem(
            title: "Haptics",
            message: "Optional light feedback helps supported keys feel more responsive."
        ),
        FeatureItem(
            title: "Shared settings",
            message: "The app and keyboard stay synchronized through shared local settings."
        ),
        FeatureItem(
            title: "Local privacy",
            message: "Clipboard data stays on device, with no analytics, cloud sync, or remote processing."
        )
    ]

    private let heroHighlights = [
        "Always-on numbers",
        "One symbols page",
        "Cursor control",
        "Local clipboard"
    ]

    var body: some View {
        VStack(spacing: 18) {
            AppHeroCard(
                eyebrow: "Features",
                title: "Typing without layout friction",
                message: "SweetKeyboard keeps the controls that interrupt daily typing closer to your fingers: numbers, symbols, cursor movement, and reusable clipboard snippets."
            ) {
                FeatureHighlightsCard(items: heroHighlights)
            }

            VStack(spacing: 12) {
                ForEach(essentialFeatures) { feature in
                    EssentialFeatureCard(feature: feature)
                }
            }

            FeatureSectionCard(
                title: "Clipboard tools",
                systemImage: "doc.on.clipboard",
                intro: "Clipboard history, pinned favorites, manual import, and one-tap paste are available when Full Access is enabled.",
                items: [
                    FeatureItem(
                        title: "History",
                        message: "Copied and imported text is saved newest first in a local grid."
                    ),
                    FeatureItem(
                        title: "Favorites",
                        message: "Pin important snippets so they stay at the top of the clipboard list."
                    ),
                    FeatureItem(
                        title: "One-tap paste",
                        message: "Tap a saved item to insert it directly into the current text field."
                    )
                ]
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

            CompactFeatureSection(items: secondaryFeatures)
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
    var id: String { title }
    let title: String
    let message: String
}

private struct EssentialFeature: Identifiable {
    var id: String { title }
    let title: String
    let message: String
    let systemImage: String
    let callout: String
}

private struct EssentialFeatureCard: View {
    let feature: EssentialFeature

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.accentSoftBackground)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(feature.callout.uppercased())
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.accent)

                        Text(feature.title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Text(feature.message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
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
                                .fill(AppTheme.accentSoftBackground)
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

private struct CompactFeatureSection: View {
    let items: [FeatureItem]
    private let columns = [
        GridItem(.adaptive(minimum: 145), spacing: 10, alignment: .top)
    ]

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Still built in")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("The smaller details stay available without competing with the main typing improvements.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        CompactFeatureTile(item: item)
                    }
                }
            }
        }
    }
}

private struct CompactFeatureTile: View {
    let item: FeatureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.message)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.innerCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.innerCardBorder, lineWidth: 1)
        )
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
                                .fill(AppTheme.accentSoftBackground)
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
                colors: [AppTheme.backgroundTop, AppTheme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private enum AppTheme {
    static let backgroundTop = adaptiveColor(light: 0xFFFFFF, dark: 0x17191D)
    static let background = adaptiveColor(light: 0xF2F4F8, dark: 0x0E1013)
    static let cardBackground = adaptiveColor(light: 0xFFFFFF, dark: 0x1B1D22, lightAlpha: 0.90, darkAlpha: 0.94)
    static let innerCardBackground = adaptiveColor(light: 0xF6F7FA, dark: 0x24272D, lightAlpha: 0.98, darkAlpha: 0.90)
    static let fieldBackground = adaptiveColor(light: 0xFFFFFF, dark: 0x22252B, lightAlpha: 0.96, darkAlpha: 0.96)
    static let accent = adaptiveColor(light: 0xF56E4A, dark: 0xFF8A66)
    static let success = adaptiveColor(light: 0x339C6B, dark: 0x52C991)
    static let primaryText = adaptiveColor(light: 0x1A263A, dark: 0xF4F5F7)
    static let secondaryText = adaptiveColor(light: 0x59667D, dark: 0xB9C0CC)
    static let tertiaryText = adaptiveColor(light: 0x8C99AD, dark: 0x737B89)
    static let cardBorder = adaptiveColor(light: 0xFFFFFF, dark: 0x30343B, lightAlpha: 0.78, darkAlpha: 0.92)
    static let innerCardBorder = adaptiveColor(light: 0xE6EAF1, dark: 0x343942, lightAlpha: 0.95, darkAlpha: 0.9)
    static let accentSoftBackground = adaptiveColor(light: 0xF56E4A, dark: 0xFF8A66, lightAlpha: 0.11, darkAlpha: 0.18)
    static let shadow = adaptiveColor(light: 0x000000, dark: 0x000000, lightAlpha: 0.08, darkAlpha: 0.28)

    private static func adaptiveColor(
        light: Int,
        dark: Int,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(hex: dark, alpha: darkAlpha)
                    : UIColor(hex: light, alpha: lightAlpha)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

#Preview {
    ContentView()
}
