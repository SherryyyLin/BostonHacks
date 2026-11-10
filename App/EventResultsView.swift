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
    @State private var filterStart: Date
    @State private var filterEnd: Date
    @State private var selectedTopic: String?
    @State private var favoritesOnly = false
    @State private var showCalendar = false
    @State private var showMap = false
    @State private var isFindingDistances = false
    @State private var message = ""

    private let topics = ["AI & Data", "Health", "Web3", "Climate", "Student", "Design & Games"]

    init(startDate: Date, endDate: Date, departureAddress: String,
         startingLatitude: Double?, startingLongitude: Double?, initialTopic: String? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.departureAddress = departureAddress
        self.startingLatitude = startingLatitude
        self.startingLongitude = startingLongitude
        self.initialTopic = initialTopic
        self._filterStart = State(initialValue: startDate)
        self._filterEnd = State(initialValue: endDate)
        self._selectedTopic = State(initialValue: initialTopic == "All" ? nil : initialTopic)
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
        .navigationTitle("Hackathon results")
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
        .task(id: distanceSignature()) { await locateVenues() }
    }

    func searchHeader() -> some View {
        return VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 9) {
            Text("YOUR NEXT CHAPTER")
                .font(.custom("Montserrat-SemiBold", size: 10)).tracking(1.8)
                .foregroundStyle(AppPalette.secondary)
            Text("Your next\nhackathon.")
                .font(.custom("Montserrat-Bold", size: 34)).lineSpacing(-1)
            Text("A date in your calendar. An idea worth building.")
                .font(.custom("Montserrat-Regular", size: 13))
                .foregroundStyle(AppPalette.ink.opacity(0.8))
        }.padding(.top, 8)

        rangeSummary()
        topicPicker()

        HStack {
            Text("\(results().count) EVENTS")
                .font(.custom("Montserrat-SemiBold", size: 11)).tracking(1)
            Spacer()
            Toggle("Saved only", isOn: $favoritesOnly)
                .font(.custom("Montserrat-Medium", size: 12))
                .fixedSize().tint(AppPalette.ink)
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
            Text("No events in this window yet.")
                .font(.custom("Montserrat-SemiBold", size: 18))
            Text("Try different dates, choose All topics, or turn off Saved only. Newly published listings appear here when live updates arrive.")
                .font(.custom("Montserrat-Regular", size: 13)).lineSpacing(4)
            if selectedTopic != nil || favoritesOnly {
                Button("Clear topic & saved filters") {
                    selectedTopic = nil
                    favoritesOnly = false
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
        }.padding(18).background(AppPalette.heroGradient, in: RoundedRectangle(cornerRadius: 22))
    }

    func topicPicker() -> some View {
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                topicButton("All", value: nil)
                ForEach(topics, id: \.self) { topic in topicButton(topic, value: topic) }
            }.padding(.vertical, 4)
        }
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
            if let distance = EventDistance.kilometers(event: event, latitude: startingLatitude, longitude: startingLongitude) {
                Label(String(format: distance < 1 ? "%.0f m away · straight-line" : "%.1f km away · straight-line", distance < 1 ? distance * 1_000 : distance), systemImage: "location")
                    .font(.custom("Montserrat-SemiBold", size: 10))
            } else if hasOrigin() && event.format != "Online" {
                Text("Venue distance unavailable").font(.custom("Montserrat-Regular", size: 10))
                    .foregroundStyle(AppPalette.ink.opacity(0.75))
            }
            Rectangle().fill(AppPalette.line).frame(height: 1)
            HStack {
                if let url = webURL(event.website) {
                    Link(destination: url) {
                        HStack(spacing: 5) {
                            Text(event.status)
                            Image(systemName: "arrow.up.right").font(.caption2)
                        }.font(.custom("Montserrat-SemiBold", size: 10)).foregroundStyle(.white)
                    }.buttonStyle(.glassProminent).tint(AppPalette.ink)
                }
                Spacer(minLength: 0)
                if event.isFavorite {
                    Image(systemName: "bookmark.fill").foregroundStyle(AppPalette.ink)
                        .accessibilityLabel("Saved event")
                }
            }
        }.padding(18).background(AppPalette.card, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).stroke(AppPalette.line.opacity(0.65)))
    }

    func results() -> [Hackathon] {
        var matches: [Hackathon] = []
        for event in topicEvents() {
            if event.startDate < filterEnd && event.endDate > filterStart && (!favoritesOnly || event.isFavorite) {
                matches.append(event)
            }
        }
        return EventDistance.nearestFirst(matches, latitude: startingLatitude, longitude: startingLongitude)
    }

    func topicEvents() -> [Hackathon] {
        guard let selectedTopic else { return events }
        var matches: [Hackathon] = []
        for event in events {
            if matchesTopic(event, topic: selectedTopic) { matches.append(event) }
        }
        return matches
    }

    func matchesTopic(_ event: Hackathon, topic: String) -> Bool {
        let combined = [event.name, event.organizer, event.notes, event.eligibility].joined(separator: " ").lowercased()
        let text = " " + combined.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ") + " "
        let keywords: [String]
        switch topic {
        case "AI & Data": keywords = [" ai ", "artificial intelligence", "machine learning", "data", "agent"]
        case "Health": keywords = ["health", "medical", "medicine", "oncology", "biosecurity", "openbio", "biotech"]
        case "Web3": keywords = ["blockchain", "web3", "crypto", "ethereum", "solana", "bitcoin"]
        case "Climate": keywords = ["sustainab", "climate", "environment", "green fund", "clean energy"]
        case "Student": keywords = ["student", "university", "college", "undergraduate", "graduate"]
        case "Design & Games": keywords = ["design", "creative", "game", "gaming", " ux ", " ui "]
        default: return true
        }
        for keyword in keywords { if text.contains(keyword) { return true } }
        return false
    }

    func hasOrigin() -> Bool {
        return startingLatitude != nil && startingLongitude != nil
    }

    func distanceSignature() -> String {
        var parts = [String(startingLatitude ?? 0), String(startingLongitude ?? 0),
                     String(filterStart.timeIntervalSince1970), String(filterEnd.timeIntervalSince1970), selectedTopic ?? "All"]
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
