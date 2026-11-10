import SwiftUI
import SwiftData

@main
struct BostonHacksApp: App {
    @State private var hasEntered = false
    var body: some Scene {
        WindowGroup {
            Group {
                if hasEntered { ContentView() }
                else { WelcomeView { hasEntered = true } }
            }
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, bostonCalendar().timeZone)
                .tint(AppPalette.accent)
                .preferredColorScheme(.light)
                .font(.custom("Montserrat-Regular", size: 14))
        }
        // Week 11: gives every screen access to the saved Hackathon models.
        .modelContainer(for: [Hackathon.self, FeedSettings.self])
    }
}
