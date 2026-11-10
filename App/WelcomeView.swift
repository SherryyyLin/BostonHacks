import SwiftUI

// Beyond the basic stack examples: TabView with .page lets people swipe through
// three welcome pages. @State keeps the selected page; no account is needed.
struct WelcomeView: View {
    let onContinue: () -> Void
    @State private var page = 0

    private let images = ["LaunchTeam", "LaunchCalendar", "LaunchMap"]
    private let titles = ["Build something\ntogether.", "Make time for\nyour next idea.", "Find your people.\nFind your place."]
    private let descriptions = [
        "Boston hackathons. Real teammates. Endless possibilities.",
        "Choose your start and end date, set a time in Boston, and find a topic that sparks your curiosity.",
        "Explore real venues with robot pins. Choose a place or ZIP code to see which hackathons are closest."
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                TabView(selection: $page) {
                    ForEach(0..<images.count, id: \.self) { index in
                        welcomePage(index, geometry: geometry)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("welcome-pages")

                HStack(spacing: 9) {
                    HStack(spacing: 9) {
                        Image(systemName: "curlybraces")
                            .font(.custom("Montserrat-Medium", size: 20))
                        Text("BOS / HACK")
                            .font(.custom("Montserrat-SemiBold", size: 12)).tracking(2.3)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                    Spacer()
                    Button(action: onContinue) {
                        Text("Skip")
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundStyle(.white).padding(.horizontal, 5)
                    }
                    .buttonStyle(.glassProminent).tint(AppPalette.ink)
                    .accessibilityIdentifier("skip-welcome")
                }
                .padding(.horizontal, 25)
                .padding(.top, geometry.safeAreaInsets.top + 16)
            }
            .background(AppPalette.card)
            .ignoresSafeArea()
        }
    }

    func welcomePage(_ index: Int, geometry: GeometryProxy) -> some View {
        return VStack(spacing: 0) {
            ZStack {
                AppPalette.heroGradient
                Image(images[index])
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.48)
                    .clipped().accessibilityHidden(true)
                LinearGradient(colors: [.black.opacity(0.24), .clear], startPoint: .top, endPoint: .center)
            }
            .frame(height: geometry.size.height * 0.48)
            .clipped()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 7) {
                        ForEach(0..<images.count, id: \.self) { dot in
                            Capsule().fill(dot == index ? AppPalette.ink : AppPalette.line)
                                .frame(width: dot == index ? 24 : 7, height: 7)
                        }
                        Spacer()
                        Text("0\(index + 1) / 03")
                            .font(.custom("Montserrat-Medium", size: 10))
                            .foregroundStyle(AppPalette.ink.opacity(0.65))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Page \(index + 1) of 3")
                    .padding(.bottom, 3)

                    Text(titles[index])
                        .font(.custom("Montserrat-Bold", size: 29)).lineSpacing(3)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(descriptions[index])
                        .font(.custom("Montserrat-Regular", size: 13)).lineSpacing(5)
                        .foregroundStyle(AppPalette.ink.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        if index == images.count - 1 {
                            onContinue()
                        } else {
                            withAnimation { page = index + 1 }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(index == images.count - 1 ? "Explore Hackathons" : "Next")
                                .font(.custom("Montserrat-SemiBold", size: 14))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.custom("Montserrat-SemiBold", size: 15))
                        }
                        .foregroundStyle(.white).padding(.horizontal, 22).frame(minHeight: 52)
                    }
                    .buttonStyle(.glassProminent).tint(AppPalette.ink)
                    .accessibilityIdentifier(index == images.count - 1 ? "explore-hackathons" : "welcome-next-\(index + 1)")
                    .padding(.top, 3)

                    Text(index == 1 ? "All event times use Boston / Eastern Time." : "No account required. Location is always optional.")
                        .font(.custom("Montserrat-Regular", size: 10)).lineSpacing(4)
                        .foregroundStyle(AppPalette.ink.opacity(0.7))
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 27).padding(.top, 27)
                .padding(.bottom, max(26, geometry.safeAreaInsets.bottom + 14))
                .frame(maxWidth: 600).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppPalette.card, in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
            .padding(.top, -24)
        }
        .background(AppPalette.card)
    }
}
