import SwiftUI
import MapKit
import CoreLocation
import Combine

// MapKit search and optional CoreLocation access extend the classroom SwiftUI examples.
// Location is requested once, only after the user confirms the dedicated button.
struct AddressSearchView: View {
    @Binding var address: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = StartingPointSearchModel()
    @State private var text = ""
    @State private var searchedZIP = ""
    @State private var mode = StartingPointSearchMode.place
    @State private var showLocationConsent = false
    @FocusState private var searchFocused: Bool

    private let cream = AppPalette.background
    private let ink = AppPalette.ink
    private let sage = AppPalette.accent
    private let muted = AppPalette.ink.opacity(0.75)
    private let line = AppPalette.line

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start from anywhere.")
                            .font(.custom("Montserrat-Bold", size: 28))
                            .foregroundStyle(ink)
                        Text("Find a place, enter a street address, or use a US ZIP code.")
                            .font(.custom("Montserrat-Regular", size: 14)).foregroundStyle(muted)
                    }

                    Picker("Search by", selection: $mode) {
                        ForEach(StartingPointSearchMode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in
                        text = ""
                        searchedZIP = ""
                        search.clearSearch()
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: mode == .zip ? "number" : "magnifyingglass")
                                .foregroundStyle(sage)
                            TextField(mode == .zip ? "ZIP code, e.g. 02115" : "Place, school, or street address", text: $text)
                                .keyboardType(mode == .zip ? .numberPad : .default)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                                .focused($searchFocused)
                                .onSubmit { runSearch() }
                                .onChange(of: text) { _, value in
                                    search.updateSuggestions(value, mode: mode)
                                }
                            if !text.isEmpty {
                                Button {
                                    text = ""
                                    search.clearSearch()
                                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(muted) }
                                .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                                .buttonBorderShape(.circle).controlSize(.mini)
                                .accessibilityLabel("Clear search")
                            }
                        }
                        .padding(16)
                        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(line, lineWidth: 1))

                        Button(action: runSearch) {
                            HStack {
                                if search.isFindingPlace { ProgressView().tint(.white) }
                                Text(mode == .zip ? "Search ZIP code" : "Search places")
                            }
                            .font(.custom("Montserrat-SemiBold", size: 15)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        .buttonStyle(.glassProminent).tint(AppPalette.ink)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || search.isFindingPlace || search.isLocating)
                        .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }

                    if let message = search.message {
                        Label(message, systemImage: "info.circle")
                            .font(.custom("Montserrat-Regular", size: 14)).foregroundStyle(muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !search.places.isEmpty {
                        resultHeading("Choose your starting point")
                        VStack(spacing: 8) {
                            ForEach(Array(search.places.enumerated()), id: \.offset) { index, place in
                                Button { search.choose(place) } label: {
                                    resultRow(title: place.name ?? "Location", subtitle: search.addressText(for: place), symbol: "mappin.and.ellipse")
                                }
                                .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                            }
                        }
                    } else if !search.suggestions.isEmpty && mode == .place {
                        resultHeading("Suggestions")
                        VStack(spacing: 8) {
                            ForEach(Array(search.suggestions.enumerated()), id: \.offset) { index, completion in
                                Button {
                                    searchFocused = false
                                    search.resolve(completion)
                                } label: {
                                    resultRow(title: completion.title, subtitle: completion.subtitle, symbol: "magnifyingglass")
                                }
                                .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                                .disabled(search.isFindingPlace)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Button { showLocationConsent = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "location.circle.fill").font(.title2)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Use my location").font(.custom("Montserrat-SemiBold", size: 15))
                                    Text("Optional · ask once for this search").font(.custom("Montserrat-Regular", size: 11))
                                }
                                Spacer()
                                if search.isLocating { ProgressView().tint(sage) }
                                else { Image(systemName: "chevron.right").font(.caption.weight(.semibold)) }
                            }
                            .foregroundStyle(ink).padding(10)
                        }
                        .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                        .disabled(search.isLocating || search.isFindingPlace)

                        Text("Searches are sent to Apple Maps. Location access is optional; manual search always works. A ZIP code uses the area's center, so routes are approximate.")
                            .font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(muted)
                    }

                    if !address.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CURRENT STARTING POINT").font(.custom("Montserrat-SemiBold", size: 10)).tracking(1)
                            Text(address).font(.custom("Montserrat-Regular", size: 14))
                        }
                        .foregroundStyle(muted).padding(.top, 4)
                    }
                }
                .padding(22)
            }
            .background(cream)
            .navigationTitle("Your starting point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Close").foregroundStyle(ink) }
                        .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                }
            }
            .confirmationDialog("Share your location with Apple location services?", isPresented: $showLocationConsent, titleVisibility: .visible) {
                Button("Continue") {
                    searchFocused = false
                    searchedZIP = ""
                    search.requestMyLocation()
                }
                .buttonStyle(.glassProminent).tint(AppPalette.ink)
                Button("Not now", role: .cancel) { }
                    .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
            } message: {
                Text("We use one location fix as your starting point. Apple receives it to look up an address. You can search by address or ZIP code instead.")
            }
            .onChange(of: search.selection) { _, selected in
                guard let selected else { return }
                address = searchedZIP.isEmpty ? selected.address : searchedZIP
                latitude = selected.latitude
                longitude = selected.longitude
                dismiss()
            }
            .onDisappear { search.cancel() }
        }
        .tint(sage)
    }

    private func runSearch() {
        searchFocused = false
        searchedZIP = mode == .zip ? text.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        search.search(text, mode: mode)
    }

    private func resultHeading(_ title: String) -> some View {
        Text(title).font(.custom("Montserrat-SemiBold", size: 11)).foregroundStyle(muted).textCase(.uppercase).tracking(1)
    }

    private func resultRow(title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(ink).frame(width: 20).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.custom("Montserrat-Medium", size: 14)).foregroundStyle(ink)
                if !subtitle.isEmpty { Text(subtitle).font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(muted) }
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).contentShape(Rectangle())
    }
}

private enum StartingPointSearchMode: String, CaseIterable, Identifiable {
    case place, zip
    var id: String { rawValue }
    var title: String { self == .place ? "Place or address" : "ZIP code" }
}

private struct ResolvedStartingPoint: Equatable {
    let address: String
    let latitude: Double
    let longitude: Double
}

@MainActor
private final class StartingPointSearchModel: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate, @preconcurrency CLLocationManagerDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var places: [MKMapItem] = []
    @Published var isFindingPlace = false
    @Published var isLocating = false
    @Published var message: String?
    @Published var selection: ResolvedStartingPoint?

    private let completer = MKLocalSearchCompleter()
    private var manager: CLLocationManager?
    private var activeSearch: MKLocalSearch?
    private var reverseRequest: MKReverseGeocodingRequest?
    private var lookupTask: Task<Void, Never>?
    private var generation = 0
    private var waitingForPermission = false
    private var awaitingFix = false
    private var isActive = true
    private var acceptsSuggestions = false
    private let bostonRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
        span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8))

    override init() {
        super.init()
        completer.delegate = self
        completer.region = bostonRegion
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateSuggestions(_ text: String, mode: StartingPointSearchMode) {
        cancelLocationLookup()
        generation += 1
        lookupTask?.cancel()
        activeSearch?.cancel()
        isFindingPlace = false
        places = []
        message = nil
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode == .place, !query.isEmpty else {
            acceptsSuggestions = false
            completer.cancel()
            suggestions = []
            return
        }
        acceptsSuggestions = true
        completer.queryFragment = query
    }

    func clearSearch() {
        cancelLocationLookup()
        generation += 1
        acceptsSuggestions = false
        completer.cancel()
        lookupTask?.cancel()
        activeSearch?.cancel()
        suggestions = []
        places = []
        message = nil
        isFindingPlace = false
    }

    func search(_ text: String, mode: StartingPointSearchMode) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let request = MKLocalSearch.Request()
        if mode == .zip {
            let digits = trimmed.replacingOccurrences(of: "-", with: "")
            guard [5, 9].contains(digits.count), digits.allSatisfy(\.isNumber) else {
                message = "Enter a five-digit US ZIP code, such as 02115. ZIP+4 is also supported."
                return
            }
            let zip = digits.count == 9 ? String(digits.prefix(5)) + "-" + String(digits.suffix(4)) : digits
            request.naturalLanguageQuery = zip + ", United States"
            request.resultTypes = .address
        } else {
            request.naturalLanguageQuery = trimmed
            request.resultTypes = [.address, .pointOfInterest]
        }
        request.region = bostonRegion
        run(request, automaticallyChoose: false)
    }

    func resolve(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = bostonRegion
        run(request, automaticallyChoose: true)
    }

    private func run(_ request: MKLocalSearch.Request, automaticallyChoose: Bool) {
        generation += 1
        let thisGeneration = generation
        lookupTask?.cancel()
        activeSearch?.cancel()
        acceptsSuggestions = false
        completer.cancel()
        let localSearch = MKLocalSearch(request: request)
        activeSearch = localSearch
        isFindingPlace = true
        message = nil
        lookupTask = Task {
            do {
                let response = try await localSearch.start()
                guard !Task.isCancelled, isActive, generation == thisGeneration else { return }
                isFindingPlace = false
                let matches = response.mapItems.filter { CLLocationCoordinate2DIsValid($0.location.coordinate) }
                guard !matches.isEmpty else {
                    message = "No matching places. Try a nearby landmark, street address, or ZIP code."
                    return
                }
                suggestions = []
                if automaticallyChoose, let first = matches.first { choose(first) }
                else { places = matches }
            } catch {
                guard !Task.isCancelled, isActive, generation == thisGeneration else { return }
                isFindingPlace = false
                message = "Search is unavailable right now. Check your connection and try again."
            }
        }
    }

    func choose(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        let fullAddress = addressText(for: item)
        selection = ResolvedStartingPoint(address: fullAddress.isEmpty ? item.name ?? "Selected location" : fullAddress,
                                         latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func addressText(for item: MKMapItem) -> String {
        item.address?.fullAddress
        ?? item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
        ?? item.name ?? ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard isActive, acceptsSuggestions, !isFindingPlace else { return }
        suggestions = Array(completer.results.prefix(8))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard isActive, acceptsSuggestions, !isFindingPlace else { return }
        suggestions = []
        message = "Suggestions are unavailable. You can still tap Search to try the full address."
    }

    func requestMyLocation() {
        guard !isLocating else { return }
        clearSearch()
        if manager == nil {
            let locationManager = CLLocationManager()
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.delegate = self
            manager = locationManager
        }
        guard let manager else { return }
        guard CLLocationManager.locationServicesEnabled() else {
            message = "Location services are off. You can enter an address or ZIP code instead."
            return
        }
        isLocating = true
        switch manager.authorizationStatus {
        case .notDetermined:
            waitingForPermission = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestOneFix()
        case .denied, .restricted:
            isLocating = false
            message = "Location access is off. Search manually, or allow access for BOS Hack in Settings."
        @unknown default:
            isLocating = false
            message = "Location is unavailable. Enter an address or ZIP code instead."
        }
    }

    private func requestOneFix() {
        guard isActive, isLocating, !awaitingFix else { return }
        waitingForPermission = false
        awaitingFix = true
        manager?.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForPermission, isActive else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: requestOneFix()
        case .denied, .restricted:
            waitingForPermission = false
            isLocating = false
            message = "No problem. You can search by place, street address, or ZIP code."
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isActive, awaitingFix else { return }
        guard let location = locations.last,
              location.horizontalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(location.coordinate) else {
            awaitingFix = false
            isLocating = false
            message = "We couldn't get a valid location. Please try an address or ZIP code."
            return
        }
        awaitingFix = false
        manager.stopUpdatingLocation()
        lookupTask?.cancel()
        generation += 1
        let thisGeneration = generation
        lookupTask = Task {
            var label = String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude)
            if let request = MKReverseGeocodingRequest(location: location) {
                reverseRequest = request
                request.preferredLocale = Locale(identifier: "en_US")
                do {
                    let items = try await request.mapItems
                    if let first = items.first {
                        let found = addressText(for: first)
                        if !found.isEmpty { label = found }
                    }
                } catch {
                    // Keep the one-time coordinate even if the optional address lookup fails.
                    print("Starting-point address lookup failed: \(error.localizedDescription)")
                }
            }
            guard !Task.isCancelled, isActive, generation == thisGeneration else { return }
            isLocating = false
            selection = ResolvedStartingPoint(address: label, latitude: location.coordinate.latitude,
                                             longitude: location.coordinate.longitude)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isActive, isLocating else { return }
        awaitingFix = false
        waitingForPermission = false
        isLocating = false
        message = "We couldn't find your location. Try again, or enter an address or ZIP code."
    }

    private func cancelLocationLookup() {
        guard isLocating else { return }
        waitingForPermission = false
        awaitingFix = false
        isLocating = false
        manager?.stopUpdatingLocation()
        reverseRequest?.cancel()
    }

    func cancel() {
        isActive = false
        generation += 1
        lookupTask?.cancel()
        activeSearch?.cancel()
        reverseRequest?.cancel()
        completer.cancel()
        manager?.stopUpdatingLocation()
        manager?.delegate = nil
    }
}
