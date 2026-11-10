import SwiftUI
import SwiftData
import MapKit

// Beyond the course: native Apple MapKit with custom robot annotations.
struct HackathonPin: Identifiable {
    let event: Hackathon
    let coordinate: CLLocationCoordinate2D
    var id: String { return event.sourceID }
}

struct HackathonMapView: View {
    let events: [Hackathon]
    let departureAddress: String
    @Binding var rangeStart: Date
    @Binding var rangeEnd: Date
    let savedOnly: Bool
    let startingLatitude: Double?
    let startingLongitude: Double?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var pins: [HackathonPin] = []
    @State private var isLoading = true
    @State private var selectedEvent: Hackathon?
    @State private var selectedLandmark: BostonLandmark?
    @State private var landmarkPins: [BostonLandmarkPin] = []
    @State private var showBostonSights = true
    @State private var showMapInfo = false
    @State private var landmarkMessage = ""
    @State private var showCalendar = false
    @State private var missingCount = 0
    @State private var message = ""
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.351, longitude: -71.105),
        span: MKCoordinateSpan(latitudeDelta: 0.24, longitudeDelta: 0.30)
    ))

    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.351, longitude: -71.105),
        span: MKCoordinateSpan(latitudeDelta: 0.24, longitudeDelta: 0.30)
    )

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rangeTitle(from: rangeStart, to: rangeEnd)).font(.custom("Montserrat-SemiBold", size: 14))
                    Text("\(pins.count) hackathon venues · tap 🤖 for details")
                        .font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(AppPalette.secondary)
                }
                Spacer()
                if isLoading { ProgressView() }
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            HStack {
                Button { showBostonSights.toggle() } label: {
                    Label(showBostonSights ? "Boston sights on" : "Boston sights off", systemImage: showBostonSights ? "sparkles" : "sparkle")
                        .font(.custom("Montserrat-SemiBold", size: 11)).foregroundStyle(AppPalette.ink)
                }
                .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                .accessibilityLabel("Boston sights, \(showBostonSights ? "on" : "off"). Toggle landmarks.")
                Spacer()
                Text("A little Boston, between builds.")
                    .font(.custom("Montserrat-Regular", size: 10)).foregroundStyle(AppPalette.secondary)
            }.padding(.horizontal, 16).padding(.bottom, 12)
            Map(position: $position) {
                if let latitude = startingLatitude, let longitude = startingLongitude {
                    Marker("Your starting point", systemImage: "location.fill", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                        .tint(AppPalette.blue)
                }
                ForEach(pins) { pin in
                    Annotation(pin.event.name, coordinate: pin.coordinate, anchor: .bottom) {
                        Button {
                            selectedLandmark = nil
                            selectedEvent = pin.event
                        } label: {
                            VStack(spacing: 2) {
                                Text("🤖").font(.custom("Montserrat-Regular", size: 28))
                                    .padding(8).background(.white, in: Circle())
                                    .overlay(Circle().stroke(AppPalette.accent, lineWidth: 2))
                                    .shadow(radius: 3, y: 2)
                                Image(systemName: "triangle.fill").font(.custom("Montserrat-Regular", size: 9))
                                    .rotationEffect(.degrees(180)).foregroundStyle(AppPalette.accent)
                            }
                        }.buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                            .buttonBorderShape(.circle)
                            .accessibilityLabel("Hackathon at \(pin.event.venue): \(pin.event.name). Open details.")
                    }
                }
                if showBostonSights {
                    ForEach(landmarkPins) { pin in
                        Annotation(pin.landmark.name, coordinate: pin.coordinate, anchor: .bottom) {
                            Button {
                                selectedEvent = nil
                                selectedLandmark = pin.landmark
                            } label: {
                                Text(pin.landmark.symbol).font(.system(size: 22))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(pin.landmark.id == "ducklings" ? AppPalette.lavender : AppPalette.dustyPink)
                            .buttonBorderShape(.circle)
                            .accessibilityLabel("Boston sight: \(pin.landmark.name). Open landmark details.")
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            HStack(spacing: 14) {
                Text("🤖 Hackathons")
                if showBostonSights { Text("🦆 Boston sights") }
                Spacer(minLength: 0)
                Button { showMapInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(AppPalette.ink)
                }.buttonStyle(.glassProminent).tint(AppPalette.frostBlue).controlSize(.mini)
                    .accessibilityLabel("Map information")
            }
            .font(.custom("Montserrat-Medium", size: 10)).foregroundStyle(AppPalette.ink)
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, missingCount > 0 ? 4 : 12)
            if missingCount > 0 {
                Text("\(missingCount) online or unlocated · unknown locations stay off the map")
                    .font(.custom("Montserrat-Regular", size: 9)).foregroundStyle(AppPalette.secondary)
                    .padding(.bottom, 10)
            }
        }
        .background(AppPalette.background)
        .navigationTitle("Hackathon map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showCalendar.toggle() } label: {
                    Label("Calendar", systemImage: "calendar").foregroundStyle(AppPalette.ink)
                }.buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: { Text("Done").foregroundStyle(AppPalette.ink) }
                    .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
            }
        }
        .task(id: eventSignature()) { await loadPins() }
        .task { await loadLandmarkPins() }
        .sheet(isPresented: $showCalendar) {
            DateRangeSheet(startDate: $rangeStart, endDate: $rangeEnd)
        }
        .sheet(item: $selectedEvent) { event in
            NavigationStack {
                EventDetailView(hackathon: event, departureAddress: departureAddress)
                    .toolbar {
                        Button { selectedEvent = nil } label: { Text("Done").foregroundStyle(AppPalette.ink) }
                            .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                    }
            }
        }
        .sheet(item: $selectedLandmark) { landmark in
            BostonLandmarkDetailView(landmark: landmark)
        }
        .sheet(isPresented: $showMapInfo) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A city worth exploring.").font(.custom("Montserrat-Bold", size: 23))
                    Text("🤖 Hackathons  ·  🦆 Ducklings  ·  🐔 MIT Museum  ·  🧱 Freedom Trail highlights")
                        .font(.custom("Montserrat-Medium", size: 12))
                    Text("Landmark pins show individual sights. Use Apple Maps for walking directions.")
                        .font(.custom("Montserrat-Regular", size: 13))
                    if !message.isEmpty { Text(message).font(.custom("Montserrat-Regular", size: 12)) }
                    if !landmarkMessage.isEmpty { Text(landmarkMessage).font(.custom("Montserrat-Regular", size: 12)) }
                    Spacer()
                }.foregroundStyle(AppPalette.ink).padding(24)
                    .background(AppPalette.background)
                    .navigationTitle("About this map").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button { showMapInfo = false } label: { Text("Done").foregroundStyle(AppPalette.ink) }
                            .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                    }
            }.presentationDetents([.medium])
        }
    }

    @MainActor
    func loadLandmarkPins() async {
        guard landmarkPins.isEmpty else { return }
        var resolved: [BostonLandmarkPin] = []
        var failures = 0
        for landmark in BostonLandmark.sights {
            guard !Task.isCancelled else { return }
            guard let request = MKGeocodingRequest(addressString: landmark.address) else {
                failures += 1
                continue
            }
            request.preferredLocale = Locale(identifier: "en_US")
            request.region = region
            do {
                let items = try await request.mapItems
                guard !Task.isCancelled else { return }
                guard let coordinate = items.first?.location.coordinate,
                      (42.2...42.5).contains(coordinate.latitude), (-71.3 ... -70.9).contains(coordinate.longitude) else {
                    failures += 1
                    continue
                }
                resolved.append(BostonLandmarkPin(landmark: landmark, coordinate: coordinate))
                landmarkPins = resolved
            } catch {
                guard !Task.isCancelled else { return }
                failures += 1
                print("ERROR: Could not locate Boston sight \(landmark.name): \(error.localizedDescription)")
            }
        }
        if failures > 0 { landmarkMessage = "Some Boston sights could not be located. Reopen the map when online to try again." }
    }

    @MainActor
    func loadPins() async {
        isLoading = true
        pins = []
        missingCount = 0
        message = ""
        var result: [HackathonPin] = []
        var missing = 0
        for event in matchingEvents() {
            if Task.isCancelled { return }
            guard event.format != "Online", !event.address.isEmpty else {
                missing += 1
                continue
            }
            if let latitude = event.latitude, let longitude = event.longitude,
               latitude.isFinite, longitude.isFinite,
               (42.0...42.8).contains(latitude), (-71.6 ... -70.7).contains(longitude) {
                result.append(HackathonPin(event: event, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
                pins = result
                continue
            }
            // Apple resolves public venue addresses. No current device location is used.
            guard let request = MKGeocodingRequest(addressString: event.address) else {
                missing += 1
                continue
            }
            request.preferredLocale = Locale(identifier: "en_US")
            request.region = region
            do {
                let items = try await request.mapItems
                if Task.isCancelled { return }
                guard let item = items.first else { missing += 1; continue }
                let coordinate = item.location.coordinate
                guard (42.0...42.8).contains(coordinate.latitude), (-71.6 ... -70.7).contains(coordinate.longitude) else {
                    missing += 1
                    continue
                }
                event.latitude = coordinate.latitude
                event.longitude = coordinate.longitude
                result.append(HackathonPin(event: event, coordinate: coordinate))
                pins = result
            } catch {
                missing += 1
                message = "Some venues could not be located. Try reopening the map when online."
                print("ERROR: Could not locate public venue \(event.address): \(error.localizedDescription)")
            }
        }
        do { try modelContext.save() }
        catch { print("ERROR: Could not cache venue coordinates: \(error.localizedDescription)") }
        pins = result
        missingCount = missing
        isLoading = false
        if !result.isEmpty { position = .automatic }
    }

    func eventSignature() -> String {
        var parts: [String] = []
        for event in matchingEvents() {
            parts.append(event.sourceID + event.address + String(event.startDate.timeIntervalSince1970))
        }
        return String(rangeStart.timeIntervalSince1970) + String(rangeEnd.timeIntervalSince1970) + parts.joined(separator: "|")
    }

    func matchingEvents() -> [Hackathon] {
        var result: [Hackathon] = []
        for event in events {
            if event.startDate < rangeEnd && event.endDate > rangeStart && (!savedOnly || event.isFavorite) {
                result.append(event)
            }
        }
        return result
    }
}

private struct BostonLandmarkDetailView: View {
    let landmark: BostonLandmark
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(landmark.symbol).font(.system(size: 48))
                Text(landmark.name).font(.custom("Montserrat-Bold", size: 25))
                Text(landmark.subtitle).font(.custom("Montserrat-Regular", size: 14)).lineSpacing(4)
                Text(landmark.address).font(.custom("Montserrat-Regular", size: 12)).foregroundStyle(AppPalette.secondary)
                if let url = mapURL {
                    Link(destination: url) {
                        Label("Open in Apple Maps", systemImage: "map")
                            .font(.custom("Montserrat-SemiBold", size: 14)).foregroundStyle(.white)
                    }.buttonStyle(.glassProminent).tint(AppPalette.ink)
                }
                if let website = landmark.website {
                    Link(destination: website) {
                        Label("Official visitor information", systemImage: "arrow.up.right")
                            .font(.custom("Montserrat-SemiBold", size: 12)).foregroundStyle(AppPalette.ink)
                    }.buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                }
                Spacer(minLength: 0)
            }.foregroundStyle(AppPalette.ink).padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.background)
                .navigationTitle("Boston sight").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button { dismiss() } label: { Text("Done").foregroundStyle(AppPalette.ink) }
                        .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                }
        }.presentationDetents([.medium, .large])
    }

    private var mapURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: landmark.address)]
        return components?.url
    }
}
