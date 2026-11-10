import SwiftUI
import SwiftData
import MapKit

// Beyond the course: native Apple MapKit with hackathon robot annotations only.
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
    // API retained for callers; only event robots are drawn.
    let startingLatitude: Double?
    let startingLongitude: Double?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var account: AccountStore
    @State private var pins: [HackathonPin] = []
    @State private var isLoading = true
    @State private var selectedEvent: Hackathon?
    @State private var showCalendar = false
    @State private var missingCount = 0
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
            Map(position: $position) {
                ForEach(pins) { pin in
                    Annotation(pin.event.name, coordinate: pin.coordinate, anchor: .bottom) {
                        Button {
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
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            if missingCount > 0 {
                Text("\(missingCount) events are online or have no confirmed map location.")
                    .font(.custom("Montserrat-Regular", size: 10)).foregroundStyle(AppPalette.secondary)
                    .padding(12)
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
    }

    @MainActor
    func loadPins() async {
        isLoading = true
        pins = []
        missingCount = 0
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
        return (account.user?.uid ?? "guest") + String(rangeStart.timeIntervalSince1970) + String(rangeEnd.timeIntervalSince1970) + parts.joined(separator: "|")
    }

    func matchingEvents() -> [Hackathon] {
        var result: [Hackathon] = []
        for event in events {
            if event.startDate < rangeEnd && event.endDate > rangeStart && (!savedOnly || account.isSaved(event)) {
                result.append(event)
            }
        }
        return result
    }
}
