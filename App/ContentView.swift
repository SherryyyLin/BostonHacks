import SwiftUI
import SwiftData

// Week 11: the Guest model pattern, extended with real dates and source information.
@Model
class Hackathon {
    var sourceID: String
    var name: String
    var organizer: String
    var startDate: Date
    var endDate: Date
    var schedule: String
    var venue: String
    var address: String
    var cost: String
    var eligibility: String
    var notes: String
    var website: String
    var sourceURL: String
    var status: String
    var format: String
    var checkedAt: Date
    var provenance: String
    var isFavorite = false
    var calendarCheckedAt: Date?
    var latitude: Double?
    var longitude: Double?

    init(event: DiscoveredEvent, provenance: String) {
        self.sourceID = event.id
        self.name = event.name
        self.organizer = event.organizer
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.schedule = event.schedule
        self.venue = event.venue
        self.address = event.address
        self.cost = event.cost
        self.eligibility = event.eligibility
        self.notes = event.notes
        self.website = event.website
        self.sourceURL = event.sourceURL
        self.status = event.status
        self.format = event.format
        self.checkedAt = event.checkedAt
        self.provenance = provenance
        self.calendarCheckedAt = provenance == "Live sources" ? event.checkedAt : nil
        self.latitude = event.latitude
        self.longitude = event.longitude
    }
}

@Model
class FeedSettings {
    var remoteFeedURL = HostedFeed.url
    init(remoteFeedURL: String = HostedFeed.url) { self.remoteFeedURL = remoteFeedURL }
}

enum HostedFeed {
    static let url = "https://raw.githubusercontent.com/SherryyyLin/BostonHacks/main/Backend/feeds/events.json"
}

struct ContentView: View {
    // Week 11: @Query reads saved models. Sorting puts real events in date order.
    @Query(sort: \Hackathon.startDate) private var hackathons: [Hackathon]
    @Query private var settings: [FeedSettings]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var departureAddress = ""
    @State private var startingLatitude: Double?
    @State private var startingLongitude: Double?
    @State private var showAddressSearch = false
    @State private var rangeStart = defaultRangeStart()
    @State private var rangeEnd = defaultRangeEnd()
    @State private var calendarStep = 0
    @State private var showCalendar = false
    @State private var datesConfirmed = false
    @State private var showResults = false
    @State private var selectedTopic: String?
    @State private var isRefreshing = false
    @State private var didLoad = false
    @State private var message = ""
    @State private var showUpdates = false
    @State private var remoteFeed = HostedFeed.url

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    homeHeader()
                    heroCard()
                    startingPointCard()
                    timeFilterCard()
                    Button {
                        showResults = true
                    } label: {
                        HStack {
                            Text("Show Events").font(.custom("Montserrat-SemiBold", size: 16))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }.frame(maxWidth: .infinity).padding(.vertical, 10).foregroundStyle(.white)
                    }
                    .buttonStyle(.glassProminent).tint(AppPalette.ink)
                    .disabled(!datesConfirmed).opacity(datesConfirmed ? 1 : 0.5)
                    .accessibilityIdentifier("show-events")
                    if !datesConfirmed {
                        Text("Choose your start and end dates to continue.")
                            .font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(AppPalette.ink.opacity(0.75))
                    }
                    topicSection()
                    updateSection()
                }
                .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 28)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .background(AppPalette.backgroundGradient)
            .foregroundStyle(AppPalette.ink)
            .navigationTitle("Plan your hackathon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .refreshable { await refreshEvents() }
            .onAppear {
                if !didLoad {
                    didLoad = true
                    remoteFeed = settings.first?.remoteFeedURL ?? HostedFeed.url
                    loadVerifiedEvents()
                }
            }
            .task {
                await refreshEvents()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(600)) }
                    catch { return }
                    if scenePhase == .active { await refreshEvents() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshEvents() } }
            }
            .sheet(isPresented: $showCalendar) {
                DateRangeSheet(startDate: $rangeStart, endDate: $rangeEnd, initialStep: calendarStep) { datesConfirmed = true }
            }
            .sheet(isPresented: $showAddressSearch) {
                AddressSearchView(address: $departureAddress, latitude: $startingLatitude, longitude: $startingLongitude)
            }
            .navigationDestination(isPresented: $showResults) {
                EventResultsView(startDate: rangeStart, endDate: rangeEnd, departureAddress: departureAddress,
                                 startingLatitude: startingLatitude, startingLongitude: startingLongitude,
                                 initialTopic: selectedTopic)
            }
        }
    }

    // Classroom HStack, VStack, shapes and Font.custom create the Morandi layout.
    func homeHeader() -> some View {
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "curlybraces").font(.title3).foregroundStyle(AppPalette.accent)
                Text("BOS / HACK").font(.system(size: 14, weight: .bold, design: .monospaced)).tracking(1)
            }
            Spacer()
            Button { Task { await refreshEvents() } } label: {
                Image(systemName: isRefreshing ? "hourglass" : "arrow.clockwise")
                    .font(.custom("Montserrat-SemiBold", size: 14)).frame(width: 42, height: 42)
                    .background(AppPalette.card, in: Circle())
            }.buttonStyle(.glassProminent).disabled(isRefreshing).accessibilityLabel("Refresh live events")
        }.foregroundStyle(AppPalette.ink)
    }

    func heroCard() -> some View {
        return ZStack(alignment: .topTrailing) {
            Circle().stroke(AppPalette.card.opacity(0.45), lineWidth: 28)
                .frame(width: 130, height: 130).offset(x: 42, y: -20)
            Circle().stroke(AppPalette.powderBlue.opacity(0.2), lineWidth: 1)
                .frame(width: 180, height: 180).offset(x: 28, y: 62)
            VStack(alignment: .leading, spacing: 13) {
                Text("THE BOSTON BUILDERS' EDIT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.8)
                Text("Boston\nHackathons.")
                    .font(.custom("Montserrat-Bold", size: 39))
                    .lineSpacing(-3).minimumScaleFactor(0.8)
                Text("Good people. Bold ideas.\nSomething worth building together.")
                    .font(.custom("Montserrat-Regular", size: 13)).lineSpacing(4)
                HStack(spacing: 6) {
                    Circle().fill(AppPalette.accent).frame(width: 5, height: 5)
                    Text("REAL EVENTS, FRESHLY FOUND")
                        .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.2)
                }.padding(.top, 7)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(25)
        }
        .foregroundStyle(AppPalette.ink)
        .background(AppPalette.heroGradient, in: RoundedRectangle(cornerRadius: 28))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    func startingPointCard() -> some View {
        return Button { showAddressSearch = true } label: {
            HStack(spacing: 13) {
                Image(systemName: "location.magnifyingglass").font(.custom("Montserrat-Regular", size: 21))
                    .frame(width: 46, height: 46)
                    .background(AppPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text(departureAddress.isEmpty ? "Where are you starting?" : "YOUR STARTING POINT")
                        .font(.system(size: departureAddress.isEmpty ? 14 : 9, weight: .semibold))
                    Text(departureAddress.isEmpty ? "Place, address or ZIP code" : departureAddress)
                        .font(.custom("Montserrat-Regular", size: 12)).multilineTextAlignment(.leading).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.foregroundStyle(AppPalette.ink).padding(17)
                .background(AppPalette.seaGlass.opacity(0.15), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppPalette.line.opacity(0.7)))
        }.buttonStyle(.glassProminent).accessibilityIdentifier("starting-point-search")
    }

    func timeFilterCard() -> some View {
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Make time for ideas.").font(.custom("Montserrat-Bold", size: 20))
                Spacer()
                Image(systemName: "calendar").foregroundStyle(AppPalette.accent)
            }
            HStack(spacing: 10) {
                rangeButton("START", date: rangeStart, step: 0)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(AppPalette.accent)
                rangeButton("END", date: rangeEnd, step: 1)
            }
            HStack {
                Button("Previous week") { moveWeek(-1) }
                Spacer()
                Button("This week") { rangeStart = defaultRangeStart(); rangeEnd = defaultRangeEnd(); datesConfirmed = true }
                Spacer()
                Button("Next week") { moveWeek(1) }
            }.font(.custom("Montserrat-Medium", size: 10)).tint(AppPalette.ink)
            Text("BOSTON TIME · ET").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
                .foregroundStyle(AppPalette.ink.opacity(0.75))
        }.padding(18).background(AppPalette.glacierBlue.opacity(0.6), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppPalette.line.opacity(0.7)))
    }

    func topicSection() -> some View {
        let topics = ["AI & Data", "Health", "Web3", "Climate", "Student", "Design & Games"]
        return VStack(alignment: .leading, spacing: 14) {
            Text("What sparks your curiosity?").font(.custom("Montserrat-Bold", size: 20))
            Text("Pick a theme, or explore everything.").font(.custom("Montserrat-Regular", size: 12))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(topics, id: \.self) { topic in
                    Button { selectedTopic = selectedTopic == topic ? nil : topic } label: {
                        Text(topic).font(.custom("Montserrat-Medium", size: 12))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(selectedTopic == topic ? Color.white : AppPalette.ink)
                    }.buttonStyle(.glassProminent)
                        .tint(selectedTopic == topic ? AppPalette.ink : AppPalette.frostBlue)
                }
            }
        }.foregroundStyle(AppPalette.ink)
    }

    func updateSection() -> some View {
        return VStack(spacing: 12) {
            if isRefreshing { ProgressView("Finding fresh events…").font(.caption).tint(AppPalette.accent) }
            Text("Real listings. Updated throughout the day.")
                .font(.custom("Montserrat-Regular", size: 11))
            Button("About & Data", systemImage: "info.circle") { showUpdates = true }
                .font(.custom("Montserrat-Medium", size: 11)).tint(AppPalette.ink)
        }.foregroundStyle(AppPalette.ink.opacity(0.8)).frame(maxWidth: .infinity).padding(.vertical, 16)
        .sheet(isPresented: $showUpdates) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Real events. Clear sources.").font(.custom("Montserrat-Bold", size: 26))
                        Text("Sources include Luma Boston, university calendars and organizer-published schedules. Activity counts change as new events are published.")
                        Text("The server checks every 3 hours. This app also checks when opened, on return, and every 10 minutes while active.")
                        Text("LinkedIn is used to discover additional leads, which are checked against organizer announcements. It is not an unattended live data source in this app.")
                            .font(.custom("Montserrat-Regular", size: 12))
                        if let linkedInURL = URL(string: "https://www.linkedin.com/search/results/content/?keywords=Boston%20hackathon") {
                            Link("Search public LinkedIn hackathon posts ↗", destination: linkedInURL)
                                .buttonStyle(.glassProminent).tint(AppPalette.frostBlue).foregroundStyle(AppPalette.ink)
                        }
                        if !message.isEmpty { Text(message).font(.caption) }
                        Text("Advanced feed settings").font(.custom("Montserrat-SemiBold", size: 16))
                TextField("HTTPS JSON feed address", text: $remoteFeed)
                    .font(.caption).textFieldStyle(.roundedBorder).keyboardType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Save and refresh") { saveFeedSettings() }.font(.caption).tint(AppPalette.ink)
                        Text("External pages and Apple Maps may use the website or device language. Luma registration links request English; the organizer's own content remains unchanged.")
                            .font(.caption)
                    }.padding(24)
                }.background(AppPalette.background)
                    .navigationTitle("About & Data").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { showUpdates = false } }
            }
        }
    }

    func saveFeedSettings() {
        let clean = remoteFeed.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            guard let url = webURL(clean), url.scheme == "https" else {
                message = "Use a valid HTTPS feed address, or leave it blank."
                return
            }
        }
        let setting = settings.first ?? FeedSettings()
        setting.remoteFeedURL = clean
        modelContext.insert(setting)
        do {
            try modelContext.save()
            Task { await refreshEvents() }
        } catch {
            modelContext.rollback()
            message = "Could not save the feed address. Please try again."
            print("ERROR: Could not save feed settings: \(error.localizedDescription)")
        }
    }

    func moveWeek(_ amount: Int) {
        guard let start = bostonCalendar().date(byAdding: .day, value: amount * 7, to: rangeStart),
              let end = bostonCalendar().date(byAdding: .day, value: amount * 7, to: rangeEnd) else {
            message = "Could not change the week. Please choose a date."
            print("😡 ERROR: Could not move calendar by \(amount) weeks.")
            return
        }
        rangeStart = start
        rangeEnd = end
        datesConfirmed = true
    }

    func rangeButton(_ title: String, date: Date, step: Int) -> some View {
        return Button {
            calendarStep = step
            showCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(dateText(date, pattern: "MMM d, yyyy")).font(.custom("Montserrat-SemiBold", size: 14))
                Text(dateText(date, pattern: "h:mm a")).font(.custom("Montserrat-Regular", size: 11))
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background((step == 0 ? AppPalette.lavender : AppPalette.dustyPink).opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(AppPalette.ink)
        }.buttonStyle(.glassProminent).tint(step == 0 ? AppPalette.lavender : AppPalette.dustyPink)
    }

    func loadVerifiedEvents() {
        guard let url = Bundle.main.url(forResource: "verified-events", withExtension: "json") else {
            message = "The verified event snapshot is missing. Try refreshing the live calendar."
            print("😡 ERROR: Missing verified-events.json")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let events = try decoder.decode([DiscoveredEvent].self, from: data)
            try saveEvents(events, provenance: "Verified research")
            message = "Organizer sources verified Nov 9, 2026. Checking for live updates…"
        } catch {
            modelContext.rollback()
            message = "Could not load the verified snapshot. Saved events are still available."
            print("😡 ERROR: Could not load verified events. \(error.localizedDescription)")
        }
    }

    // Networking is outside the slides and isolated in LiveEventService.swift.
    func refreshEvents() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        do {
            let configuredURL = remoteFeed.isEmpty ? nil : webURL(remoteFeed)
            let report = try await LiveEventService.fetchReport(feedURL: configuredURL)
            try saveEvents(report.events, provenance: "Live sources")
            message = "Checked \(dateText(Date(), pattern: "MMM d, h:mm a")) ET · \(report.events.count) live hackathon listings received. Sources: \(report.successfulSources.joined(separator: ", "))."
            if !report.failedSources.isEmpty {
                message += " Unavailable: \(report.failedSources.joined(separator: ", ")). Saved listings retained."
            }
        } catch {
            modelContext.rollback()
            message = "Live refresh unavailable. Showing saved and verified listings. \(error.localizedDescription)"
            print("😡 ERROR: Could not refresh live events. \(error.localizedDescription)")
        }
        isRefreshing = false
    }

    func saveEvents(_ incoming: [DiscoveredEvent], provenance: String) throws {
        // Fetch synchronously: @Query can still be refreshing after an earlier save.
        var stored = try modelContext.fetch(FetchDescriptor<Hackathon>())
        var unique: [Hackathon] = []
        for candidate in stored {
            if let duplicate = unique.first(where: { samePublishedEvent($0, candidate) }) {
                // Preserve bookmarks while merging old feed IDs into one researched event.
                if candidate.provenance == "Verified research" && duplicate.provenance != "Verified research" {
                    candidate.isFavorite = candidate.isFavorite || duplicate.isFavorite
                    unique.removeAll(where: { $0 === duplicate })
                    modelContext.delete(duplicate)
                    unique.append(candidate)
                } else {
                    duplicate.isFavorite = duplicate.isFavorite || candidate.isFavorite
                    modelContext.delete(candidate)
                }
            } else { unique.append(candidate) }
        }
        stored = unique
        for event in incoming {
            var existing: Hackathon?
            for hackathon in stored {
                if hackathon.sourceID == event.id || sameTitleAndDay(hackathon.name, date: hackathon.startDate, otherName: event.name, otherDate: event.startDate) {
                    existing = hackathon
                }
            }
            if let existing {
                if provenance == "Live sources" && event.checkedAt > existing.checkedAt {
                    existing.calendarCheckedAt = event.checkedAt
                    if event.status != "Check organizer page" && event.status != "Check organizer" && !event.status.isEmpty {
                        existing.status = event.status
                    }
                    if let latitude = event.latitude, let longitude = event.longitude {
                        existing.latitude = latitude
                        existing.longitude = longitude
                    }
                    if existing.cost.localizedCaseInsensitiveContains("check") && event.cost == "Free" {
                        existing.cost = "Free"
                    }
                    let calendar = bostonCalendar()
                    let changedDays = !calendar.isDate(existing.startDate, inSameDayAs: event.startDate) ||
                        !calendar.isDate(existing.endDate.addingTimeInterval(-1), inSameDayAs: event.endDate.addingTimeInterval(-1))
                    if changedDays {
                        // A rescheduled event must move to the correct week immediately.
                        existing.provenance = "Live sources"
                    }
                }
                // Keep richer research details; update entries originally discovered by the feed.
                if existing.provenance == "Live sources" && provenance == "Live sources" && event.checkedAt >= existing.checkedAt {
                    existing.name = event.name
                    existing.startDate = event.startDate
                    existing.endDate = event.endDate
                    existing.schedule = event.schedule
                    existing.venue = event.venue
                    if existing.address != event.address {
                        existing.latitude = nil
                        existing.longitude = nil
                    }
                    existing.address = event.address
                    existing.notes = event.notes
                    existing.website = event.website
                    existing.sourceURL = event.sourceURL
                    existing.status = event.status
                    existing.checkedAt = event.checkedAt
                    existing.format = event.format
                    existing.organizer = event.organizer
                    existing.cost = event.cost
                    existing.eligibility = event.eligibility
                    if let latitude = event.latitude, let longitude = event.longitude {
                        existing.latitude = latitude
                        existing.longitude = longitude
                    }
                }
            } else {
                let newEvent = Hackathon(event: event, provenance: provenance)
                modelContext.insert(newEvent)
                stored.append(newEvent)
            }
        }
        try modelContext.save()
    }

    func samePublishedEvent(_ first: Hackathon, _ second: Hackathon) -> Bool {
        if first.sourceID == second.sourceID { return true }
        return sameTitleAndDay(first.name, date: first.startDate, otherName: second.name, otherDate: second.startDate)
    }

    func sameTitleAndDay(_ name: String, date: Date, otherName: String, otherDate: Date) -> Bool {
        guard bostonCalendar().isDate(date, inSameDayAs: otherDate) else { return false }
        let firstName = name.lowercased().filter { $0.isLetter || $0.isNumber }
        let secondName = otherName.lowercased().filter { $0.isLetter || $0.isNumber }
        return firstName.count > 18 && secondName.count > 18 &&
            (firstName.contains(secondName) || secondName.contains(firstName))
    }
}

struct EventDetailView: View {
    let hackathon: Hackathon
    let departureAddress: String
    @Environment(\.modelContext) private var modelContext
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(hackathon.format.uppercased()).font(.caption).bold().foregroundStyle(AppPalette.accent)
                Text(hackathon.name).font(.custom("Montserrat-Bold", size: 32))
                Text(hackathon.organizer).font(.subheadline).foregroundStyle(.secondary)
                if let url = webURL(hackathon.website) {
                    Link(hackathon.status + " ↗", destination: url)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 15).padding(.vertical, 12)
                        .background(AppPalette.powderBlue.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                        .buttonStyle(.glassProminent)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(hackathon.schedule).bold()
                    Text("Times are in Boston / Eastern Time.").font(.caption).foregroundStyle(.secondary)
                    Text(hackathon.venue)
                    if !hackathon.address.isEmpty { Text(hackathon.address).font(.subheadline) }
                    HStack {
                        Text("Cost:")
                        if hackathon.cost.localizedCaseInsensitiveContains("check") || hackathon.cost.localizedCaseInsensitiveContains("see organizer") {
                            if let url = webURL(hackathon.website) { Link("Check cost ↗", destination: url).buttonStyle(.glassProminent).tint(AppPalette.frostBlue).foregroundStyle(AppPalette.ink) }
                        } else { Text(hackathon.cost) }
                    }
                    if hackathon.eligibility.localizedCaseInsensitiveContains("see organizer") || hackathon.eligibility.localizedCaseInsensitiveContains("check organizer") {
                        if let url = webURL(hackathon.website) { Link("Check eligibility ↗", destination: url).buttonStyle(.glassProminent).tint(AppPalette.frostBlue).foregroundStyle(AppPalette.ink) }
                    } else { Text("Eligibility: \(hackathon.eligibility)").font(.subheadline) }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.accent.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 18))
                Text("About the event").font(.title2).bold()
                Text(eventDescription(hackathon.notes))
                Button(hackathon.isFavorite ? "Remove from saved" : "Save event", systemImage: "bookmark") {
                    toggleFavorite()
                }.buttonStyle(.glassProminent).tint(AppPalette.ink).foregroundStyle(.white)
                if let url = webURL(hackathon.website) {
                    Link("Registration & event page ↗", destination: url)
                        .buttonStyle(.glassProminent).tint(AppPalette.ink).foregroundStyle(.white)
                }
                if hackathon.format != "Online" && !hackathon.address.isEmpty {
                    Text("Getting there").font(.title2).bold()
                    Text(departureAddress.isEmpty ? "Enter your starting address on the home screen to enable directions." : "From: \(departureAddress)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let url = mapsURL(from: departureAddress, to: hackathon.address) {
                        Link(destination: url) {
                            Label("Open transit directions", systemImage: "map.fill")
                                .font(.custom("Montserrat-SemiBold", size: 13)).foregroundStyle(.white)
                        }
                            .buttonStyle(.glassProminent).tint(AppPalette.ink)
                            .disabled(departureAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Directions use your chosen starting point and share both addresses with Apple Maps. Location access is requested only when you choose Use my location; manual address or ZIP search is always available.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Source & freshness").font(.title2).bold()
                if let url = webURL(hackathon.sourceURL) {
                    Link("View original source ↗", destination: url)
                        .buttonStyle(.glassProminent).tint(AppPalette.frostBlue).foregroundStyle(AppPalette.ink)
                }
                Text("\(hackathon.provenance) · checked \(dateText(hackathon.checkedAt, pattern: "MMM d, yyyy"))")
                    .font(.caption).foregroundStyle(.secondary)
                if let checked = hackathon.calendarCheckedAt {
                    Text("Also checked in live sources: \(dateText(checked, pattern: "MMM d, h:mm a")) ET. Research details keep their original verification date.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Availability and details may change. The organizer's page is the final authority.")
                    .font(.caption).foregroundStyle(.secondary)
                if !message.isEmpty { Text(message).foregroundStyle(.red) }
            }.padding(22)
        }
        .background(AppPalette.background)
        .foregroundStyle(AppPalette.ink)
        .navigationTitle("Event details")
        .toolbar(.visible, for: .navigationBar)
    }

    func toggleFavorite() {
        hackathon.isFavorite = !hackathon.isFavorite
        do {
            try modelContext.save()
            message = ""
        } catch {
            modelContext.rollback()
            message = "Could not save this change. Please try again."
            print("😡 ERROR: Could not save favorite for \(hackathon.name). \(error.localizedDescription)")
        }
    }

    func eventDescription(_ notes: String) -> String {
        return notes.replacingOccurrences(of: "; stored day boundaries are for calendar filtering only", with: "")
            .replacingOccurrences(of: "stored day boundaries are for calendar filtering only. ", with: "")
    }
}

// These date helpers extend the classroom DatePicker with real Monday–Sunday weeks.
func bostonCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}

func defaultRangeStart() -> Date {
    return bostonCalendar().dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
}

func defaultRangeEnd() -> Date {
    return bostonCalendar().dateInterval(of: .weekOfYear, for: Date())?.end ?? Date().addingTimeInterval(604_800)
}

func rangeTitle(from start: Date, to end: Date) -> String {
    return dateText(start, pattern: "MMM d, h:mm a") + " → " + dateText(end, pattern: "MMM d, h:mm a")
}

func dateText(_ date: Date, pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = bostonCalendar().timeZone
    formatter.dateFormat = pattern
    return formatter.string(from: date)
}

func weekTitle(_ date: Date) -> String {
    guard let week = bostonCalendar().dateInterval(of: .weekOfYear, for: date),
          let lastDay = bostonCalendar().date(byAdding: .day, value: -1, to: week.end) else {
        return "Choose a date"
    }
    return dateText(week.start, pattern: "MMM d") + " – " + dateText(lastDay, pattern: "MMM d, yyyy")
}

// Beyond the slides: Link opens a validated external webpage.
func webURL(_ text: String) -> URL? {
    guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
          let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else {
        print("😡 ERROR: Invalid website URL: \(text)")
        return nil
    }
    if host.lowercased() == "luma.com" || host.lowercased() == "lu.ma" {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        items.removeAll { $0.name == "locale" }
        items.append(URLQueryItem(name: "locale", value: "en"))
        components?.queryItems = items
        return components?.url ?? url
    }
    return url
}

// Beyond the slides: encode spaces, #, & and non-English addresses safely.
func mapsURL(from departure: String, to destination: String) -> URL? {
    guard var components = URLComponents(string: "maps://") else {
        print("😡 ERROR: Could not create Apple Maps URL.")
        return nil
    }
    components.queryItems = [URLQueryItem(name: "saddr", value: departure.trimmingCharacters(in: .whitespacesAndNewlines)),
                             URLQueryItem(name: "daddr", value: destination), URLQueryItem(name: "dirflg", value: "r")]
    guard let url = components.url else {
        print("😡 ERROR: Could not encode map addresses.")
        return nil
    }
    return url
}
