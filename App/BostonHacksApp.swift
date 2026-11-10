import SwiftUI
import SwiftData
import FirebaseCore

@main
struct BostonHacksApp: App {
    @State private var hasEntered = false
    @State private var browsingAsGuest = false
    @StateObject private var account: AccountStore

    init() {
        if FirebaseApp.app() == nil, Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        _account = StateObject(wrappedValue: AccountStore())
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if !hasEntered { WelcomeView { hasEntered = true } }
                else if account.user == nil && !browsingAsGuest { AccountView { browsingAsGuest = true } }
                else { ContentView() }
            }
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, bostonCalendar().timeZone)
                .tint(AppPalette.accent)
                .preferredColorScheme(.light)
                .font(.custom("Montserrat-Regular", size: 14))
                .buttonStyle(.glassProminent)
                .environmentObject(account)
        }
        // Week 11: gives every screen access to the saved Hackathon models.
        .modelContainer(for: [Hackathon.self, FeedSettings.self])
    }
}
