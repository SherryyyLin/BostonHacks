import SwiftUI
import SwiftData

struct EventResultsView: View {
    let startDate: Date
    let endDate: Date
    let departureAddress: String
    let startingLatitude: Double?
    let startingLongitude: Double?
    var initialTopic: String? = nil

    // Classroom @Query + @State: live saved models, with this screen's filters.
    @Query(sort: \Hackathon.startDate) private var events: [Hackathon]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var account: AccountStore
    @State private var filterStart: Date
    @State private var filterEnd: Date
    @State private var selectedTopic: String?
    @State private var favoritesOnly = false
    @State private var showCalendar = false
    @State private var showMap = false
    @State private var showAccount = false
    @State private var isFindingDistances = false
    @State private var message = ""

    private let topics = EventTopic.names

    init(startDate: Date, endDate: Date, departureAddress: String,
         startingLatitude: Double?, startingLongitude: Double?, initialTopic: String? = nil, savedOnly: Bool = false) {
        self.startDate = startDate
        self.endDate = endDate
        self.departureAddress = departureAddress
        self.startingLatitude = startingLatitude
        self.startingLongitude = startingLongitude
        self.initialTopic = initialTopic
        self._filterStart = State(initialValue: startDate)
        self._filterEnd = State(initialValue: endDate)
        self._selectedTopic = State(initialValue: EventTopic.names.contains(initialTopic ?? "") ? initialTopic : nil)
        self._favoritesOnly = State(initialValue: savedOnly)
    }

    var body: some View {
        // Week 11: List owns real rows; ForEach creates one row per event.
        // The parent NavigationStack supplies push navigation to event details.
        List {
            searchHeader()
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 14, trailing: 22))

            if results().isEmpty {
                emptyResults()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 8, trailing: 22))
            }

            ForEach(results()) { event in
                eventCard(event)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 8, trailing: 22))
            }

            VStack(alignment: .leading, spacing: 12) {
                if !message.isEmpty {
                    Text(message).font(.custom("Montserrat-Regular", size: 11))
                        .foregroundStyle(AppPalette.ink.opacity(0.8))
                }
                Text("Live listings update automatically. Check the organizer's page for final availability and eligibility. Topic filters use keywords in each listing.")
                    .font(.custom("Montserrat-Regular", size: 10)).lineSpacing(3)
                    .foregroundStyle(AppPalette.ink.opacity(0.8))
            }
            .padding(.vertical, 10)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 24, trailing: 22))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppPalette.backgroundGradient).foregroundStyle(AppPalette.ink)
        .navigationTitle(favoritesOnly ? "Saved events" : "Hackathon results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(AppPalette.ink)
        .sheet(isPresented: $showCalendar) {
            DateRangeSheet(startDate: $filterStart, endDate: $filterEnd)
        }
        .sheet(isPresented: $showMap) {
            NavigationStack {
                HackathonMapView(events: topicEvents(), departureAddress: departureAddress,
                                 rangeStart: $filterStart, rangeEnd: $filterEnd, savedOnly: favoritesOnly,
                                 startingLatitude: startingLatitude, startingLongitude: startingLongitude)
            }
        }
        .sheet(isPresented: $showAccount) { AccountView() }
        .onChange(of: account.user?.uid) { _, uid in
            if uid == nil && favoritesOnly { showAccount = true }
        }
        .onAppear { if favoritesOnly && account.user == nil { showAccount = true } }
        .task(id: distanceSignature()) { await locateVenues() }
    }

    func searchHeader() -> some View {
        return VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 9) {
            Text("YOUR NEXT CHAPTER")
                .font(.custom("Montserrat-SemiBold", size: 10)).tracking(1.8)
                .foregroundStyle(AppPalette.secondary)
            Text(favoritesOnly ? "Saved for\nlater." : "Your next\nhackathon.")
                .font(.custom("Montserrat-Bold", size: 34)).lineSpacing(-1)
            Text(favoritesOnly ? "Your favorites, ready when you are." : "A date in your calendar. An idea worth building.")
                .font(.custom("Montserrat-Regular", size: 13))
                .foregroundStyle(AppPalette.ink.opacity(0.8))
        }.padding(.top, 8)

        rangeSummary()
        dayPicker()
        topicPicker()

        HStack {
            Text("\(results().count) \(favoritesOnly ? "SAVED EVENTS" : "EVENTS")")
                .font(.custom("Montserrat-SemiBold", size: 11)).tracking(1)
            Spacer()
        }

        if hasOrigin() {
            VStack(alignment: .leading, spacing: 5) {
                Text("Nearest first · straight-line distance")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                Text(departureAddress.isEmpty ? "From your selected starting point" : "From \(departureAddress)")
                    .font(.custom("Montserrat-Regular", size: 11)).lineLimit(2)
                if isFindingDistances {
                    ProgressView("Locating published venues…")
                        .font(.custom("Montserrat-Regular", size: 11)).tint(AppPalette.ink)
                }
            }.foregroundStyle(AppPalette.ink.opacity(0.8))
        } else {
            Text("Earliest first · choose a starting point on Home for nearby results.")
                .font(.custom("Montserrat-Regular", size: 11))
                .foregroundStyle(AppPalette.ink.opacity(0.8))
        }

        Button {
            showMap = true
        } label: {
            Label("Explore these events on the map", systemImage: "map")
                .font(.custom("Montserrat-SemiBold", size: 13))
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent).tint(AppPalette.ink)
        .accessibilityIdentifier("results-map")
        }
    }

    func emptyResults() -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "calendar.badge.magnifyingglass").font(.title)
            Text(favoritesOnly && account.user == nil ? "Sign in to see your saved events." : isAllSavedDates() ? "No saved events yet." : favoritesOnly ? "No saved events in this window yet." : "No events in this window yet.")
                .font(.custom("Montserrat-SemiBold", size: 18))
            Text(favoritesOnly && account.user == nil ? "Your saved hackathons belong to your account and sync across your devices." : "Try a different day, edit your date range, or choose All topics. New listings appear when live updates arrive.")
                .font(.custom("Montserrat-Regular", size: 13)).lineSpacing(4)
            if favoritesOnly && account.user == nil {
                Button("Sign in") { showAccount = true }
                    .font(.custom("Montserrat-SemiBold", size: 12)).foregroundStyle(.white)
                    .buttonStyle(.glassProminent).tint(AppPalette.ink)
            } else if selectedTopic != nil {
                Button("Show all topics") {
                    selectedTopic = nil
                }
                .font(.custom("Montserrat-SemiBold", size: 12)).foregroundStyle(.white)
                .buttonStyle(.glassProminent).tint(AppPalette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 22))
    }

    func rangeSummary() -> some View {
        return VStack(alignment: .leading, spacing: 14) {
            if isAllSavedDates() {
                Label("All saved events", systemImage: "bookmark.fill")
                    .font(.custom("Montserrat-SemiBold", size: 17))
                Text("Every date. Choose a day below to narrow your favorites.")
                    .font(.custom("Montserrat-Regular", size: 12)).lineSpacing(3)
            } else {
              HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("START").font(.custom("Montserrat-SemiBold", size: 9)).tracking(1)
                    Text(dateText(filterStart, pattern: "MMM d, yyyy"))
                        .font(.custom("Montserrat-SemiBold", size: 13))
                    Text(dateText(filterStart, pattern: "h:mm a"))
                        .font(.custom("Montserrat-Regular", size: 12))
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right").font(.caption).padding(.top, 20)
                VStack(alignment: .leading, spacing: 6) {
                    Text("END").font(.custom("Montserrat-SemiBold", size: 9)).tracking(1)
                    Text(dateText(filterEnd, pattern: "MMM d, yyyy"))
                        .font(.custom("Montserrat-SemiBold", size: 13))
                    Text(dateText(filterEnd, pattern: "h:mm a"))
                        .font(.custom("Montserrat-Regular", size: 12))
                }.frame(maxWidth: .infinity, alignment: .leading)
              }
              HStack {
                Text("BOSTON TIME · ET").font(.custom("Montserrat-Medium", size: 9))
                Spacer()
                Button {
                    showCalendar = true
                } label: {
                    Label("Edit dates", systemImage: "calendar")
                        .font(.custom("Montserrat-SemiBold", size: 11)).foregroundStyle(.white)
                }.buttonStyle(.glassProminent).tint(AppPalette.ink)
                    .accessibilityIdentifier("results-edit-dates")
              }
            }
        }.padding(18).background(AppPalette.heroGradient, in: RoundedRectangle(cornerRadius: 22))
    }

    func isAllSavedDates() -> Bool {
        return favoritesOnly && filterStart == Date.distantPast && filterEnd == Date.distantFuture
    }

    func topicPicker() -> some View {
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                topicButton("All", value: nil)
                ForEach(topics, id: \.self) { topic in topicButton(topic, value: topic) }
            }.padding(.vertical, 4)
        }
    }

    func dayPicker() -> some View {
        return VStack(alignment: .leading, spacing: 10) {
            Text("PICK A DAY").font(.custom("Montserrat-SemiBold", size: 10)).tracking(1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(upcomingDays(), id: \.self) { date in dayButton(date) }
                }.padding(.vertical, 5)
            }
        }
    }

    func dayButton(_ date: Date) -> some View {
        let calendar = bostonCalendar()
        let selected = calendar.isDate(filterStart, inSameDayAs: date) && filterStart == calendar.startOfDay(for: date) &&
            calendar.date(byAdding: .day, value: 1, to: filterStart) == filterEnd
        return Button {
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                message = "Could not select this day. Please use Edit dates."
                print("ERROR: Could not form a Boston day interval.")
                return
            }
            filterStart = start
            filterEnd = end
        } label: {
            VStack(spacing: 6) {
                Text(calendar.isDateInToday(date) ? "Today" : dateText(date, pattern: "EEE"))
                    .font(.custom("Montserrat-SemiBold", size: 10))
                Text(dateText(date, pattern: "d")).font(.custom("Montserrat-SemiBold", size: 23))
                Text(dateText(date, pattern: "MMM").uppercased())
                    .font(.custom("Montserrat-Medium", size: 9))
            }.foregroundStyle(AppPalette.ink).frame(minWidth: 51).padding(.vertical, 7)
        }
        .buttonStyle(.glassProminent).tint(selected ? AppPalette.lavender : AppPalette.dustyPink.opacity(0.5))
        .accessibilityLabel(dateText(date, pattern: "EEEE, MMMM d, yyyy"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func upcomingDays() -> [Date] {
        let calendar = bostonCalendar()
        let today = calendar.startOfDay(for: Date())
        var days: [Date] = []
        for offset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) { days.append(date) }
        }
        return days
    }

    func topicButton(_ title: String, value: String?) -> some View {
        let selected = selectedTopic == value
        return Button {
            selectedTopic = value
        } label: {
            Text(title).font(.custom("Montserrat-SemiBold", size: 11))
                .foregroundStyle(selected ? .white : AppPalette.ink).padding(.vertical, 3)
        }
        .buttonStyle(.glassProminent).tint(selected ? AppPalette.ink : AppPalette.frostBlue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func eventCard(_ event: Hackathon) -> some View {
        return VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                EventDetailView(hackathon: event, departureAddress: departureAddress)
            } label: {
                HStack(alignment: .top, spacing: 13) {
                    VStack(spacing: 3) {
                        Text(dateText(event.startDate, pattern: "MMM").uppercased())
                            .font(.custom("Montserrat-SemiBold", size: 9))
                        Text(dateText(event.startDate, pattern: "dd"))
                            .font(.custom("Montserrat-Medium", size: 27))
                    }.frame(width: 57, height: 66)
                        .background(AppPalette.frostBlue.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(event.format.uppercased())
                            .font(.custom("Montserrat-SemiBold", size: 9)).tracking(0.7)
                        Text(event.name).font(.custom("Montserrat-SemiBold", size: 16))
                        Text(event.venue).font(.custom("Montserrat-Regular", size: 11)).lineLimit(2)
                    }.multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption)
                }.foregroundStyle(AppPalette.ink)
            }.buttonStyle(.plain)
            Text(event.schedule).font(.custom("Montserrat-Regular", size: 11))
                .foregroundStyle(AppPalette.ink.opacity(0.8))
            if let team = teamSummary(event.eligibility) {
                Label(team, systemImage: "person.3.fill")
                    .font(.custom("Montserrat-Regular", size: 11)).lineLimit(2)
                    .foregroundStyle(AppPalette.ink.opacity(0.8))
            }
            if let distance = EventDistance.kilometers(event: event, latitude: startingLatitude, longitude: startingLongitude) {
                Label(String(format: distance < 1 ? "%.0f m away · straight-line" : "%.1f km away · straight-line", distance < 1 ? distance * 1_000 : distance), systemImage: "location")
                    .font(.custom("Montserrat-SemiBold", size: 10))
            } else if hasOrigin() && event.format != "Online" {
                Text("Venue distance unavailable").font(.custom("Montserrat-Regular", size: 10))
                    .foregroundStyle(AppPalette.ink.opacity(0.75))
            }
            Rectangle().fill(AppPalette.line).frame(height: 1)
            HStack {
                EventStatusView(event: event)
                Spacer(minLength: 0)
                if account.isSaved(event) {
                    Image(systemName: "bookmark.fill").foregroundStyle(AppPalette.ink)
                        .accessibilityLabel("Saved event")
                }
            }
        }.padding(18).background(AppPalette.card, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).stroke(AppPalette.line.opacity(0.65)))
    }

    func teamSummary(_ eligibility: String) -> String? {
        guard let range = eligibility.range(of: "team", options: .caseInsensitive) else { return nil }
        let remaining = String(eligibility[range.lowerBound...])
        return remaining.components(separatedBy: CharacterSet(charactersIn: ".;")).first
    }

    func results() -> [Hackathon] {
        var matches: [Hackathon] = []
        for event in topicEvents() {
            if event.startDate < filterEnd && event.endDate > filterStart && (!favoritesOnly || account.isSaved(event)) {
                matches.append(event)
            }
        }
        return EventDistance.nearestFirst(matches, latitude: startingLatitude, longitude: startingLongitude)
    }

    func topicEvents() -> [Hackathon] {
        guard let selectedTopic else { return events }
        var matches: [Hackathon] = []
        for event in events {
            if EventTopic.category(for: event) == selectedTopic { matches.append(event) }
        }
        return matches
    }

    func hasOrigin() -> Bool {
        return startingLatitude != nil && startingLongitude != nil
    }

    func distanceSignature() -> String {
        var parts = [String(startingLatitude ?? 0), String(startingLongitude ?? 0),
                     String(filterStart.timeIntervalSince1970), String(filterEnd.timeIntervalSince1970), selectedTopic ?? "All",
                     account.user?.uid ?? "guest", favoritesOnly ? "saved" : "all"]
        if favoritesOnly { parts.append(account.savedIDs.sorted().joined(separator: ",")) }
        for event in topicEvents() {
            if event.startDate < filterEnd && event.endDate > filterStart {
                parts.append(event.sourceID + event.address + String(event.startDate.timeIntervalSince1970))
            }
        }
        return parts.joined(separator: "|")
    }

    func locateVenues() async {
        guard hasOrigin() else { return }
        isFindingDistances = true
        let resolved = await EventDistance.resolveMissingCoordinates(in: results())
        guard !Task.isCancelled else { return }
        if resolved > 0 {
            do { try modelContext.save() }
            catch {
                message = "Venue distances are available for this session; they could not be cached."
                print("ERROR: Could not cache results venue coordinates: \(error.localizedDescription)")
            }
        }
        isFindingDistances = false
    }
}
