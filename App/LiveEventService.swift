import Foundation

// Extra beyond the course: URLSession downloads a public organizer calendar.
// This small transport model keeps web parsing separate from the class-style UI.
struct DiscoveredEvent: Codable, Sendable {
    var id: String
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
    var latitude: Double? = nil
    var longitude: Double? = nil
}

struct LiveRefreshReport: Sendable {
    var events: [DiscoveredEvent]
    var successfulSources: [String]
    var failedSources: [String]
}

enum LiveEventService {
    static let calendarURLString = "https://api.lu.ma/ics/get?entity=calendar&id=cal-qk07YDF6ZivCcE0"
    static let organizerURLString = "https://the-open-accelerator.com/calendar/"
    private static let maximumBytes = 2_000_000

    static func fetchEvents() async throws -> [DiscoveredEvent] {
        return try await fetchReport().events
    }

    // Each public source can fail independently; a healthy source still updates the app.
    static func fetchReport(feedURL: URL? = nil) async throws -> LiveRefreshReport {
        var sources: [(String, String, SourceKind)] = [
            ("TOA organizer calendar", calendarURLString, .calendar),
            ("Luma Boston discovery", lumaURL(query: nil, cursor: nil), .luma),
            ("Luma Boston hackathon search", lumaURL(query: "hackathon", cursor: nil), .luma),
            ("Luma Boston datathon search", lumaURL(query: "datathon", cursor: nil), .luma),
            ("Luma Boston game jam search", lumaURL(query: "game jam", cursor: nil), .luma)
        ]
        if let feedURL {
            sources.append(("Hosted continuous collector", feedURL.absoluteString, .array))
        }
        let outcomes = await withTaskGroup(of: SourceOutcome.self) { group in
            for (name, url, kind) in sources {
                group.addTask {
                    do {
                        let data = try await download(url, accept: kind == .calendar ? "text/calendar" : "application/json")
                        let events: [DiscoveredEvent]
                        switch kind {
                        case .calendar:
                            events = try parseCalendar(data, checkedAt: Date())
                        case .luma:
                            events = try await fetchLumaPages(initialData: data, initialURL: url)
                        case .array:
                            events = try parseHostedFeed(data)
                        }
                        return SourceOutcome(name: name, events: events, error: nil)
                    } catch {
                        print("ERROR: \(name) failed: \(error.localizedDescription)")
                        return SourceOutcome(name: name, events: [], error: error.localizedDescription)
                    }
                }
            }
            var collected: [SourceOutcome] = []
            for await outcome in group {
                collected.append(outcome)
            }
            return collected
        }
        var successful: [String] = []
        var failed: [String] = []
        var byID: [String: DiscoveredEvent] = [:]
        for outcome in outcomes.sorted(by: { $0.name < $1.name }) {
            if let error = outcome.error {
                failed.append("\(outcome.name): \(error)")
            } else {
                successful.append(outcome.name)
                for event in outcome.events {
                    // Duplicate URLs from chronological/search pages remain one event.
                    if byID[event.id] == nil || event.checkedAt > (byID[event.id]?.checkedAt ?? .distantPast) {
                        byID[event.id] = event
                    }
                }
            }
        }
        guard !successful.isEmpty else {
            throw CalendarError.allSourcesFailed(failed)
        }
        let events = byID.values.sorted { first, second in
            if first.startDate == second.startDate { return first.id < second.id }
            return first.startDate < second.startDate
        }
        return LiveRefreshReport(events: events, successfulSources: successful, failedSources: failed)
    }

    private static func download(_ string: String, accept: String) async throws -> Data {
        guard let url = URL(string: string), url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil else {
            print("ERROR: Invalid public source URL: \(string)")
            throw CalendarError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              http.url?.scheme?.lowercased() == "https" else {
            throw CalendarError.invalidResponse
        }
        guard response.expectedContentLength <= Int64(maximumBytes) else {
            throw CalendarError.tooLarge
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw CalendarError.tooLarge }
            data.append(byte)
        }
        return data
    }

    private enum SourceKind: Sendable { case calendar, luma, array }
    private struct SourceOutcome: Sendable {
        var name: String
        var events: [DiscoveredEvent]
        var error: String?
    }

    // Public endpoint observed in the JavaScript used by luma.com/boston.
    // This is a website discovery feed, so schema failures are reported rather
    // than silently replacing real events with a fabricated list.
    private static func lumaURL(query: String?, cursor: String?) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.luma.com"
        components.path = "/discover/get-paginated-events"
        var items = [URLQueryItem(name: "discover_place_api_id", value: "discplace-VWeZ1zUvnawYHMj"),
                     URLQueryItem(name: "pagination_limit", value: "25")]
        if let query { items.append(URLQueryItem(name: "query", value: query)) }
        if let cursor { items.append(URLQueryItem(name: "pagination_cursor", value: cursor)) }
        components.queryItems = items
        return components.string ?? ""
    }

    private static func fetchLumaPages(initialData: Data, initialURL: String) async throws -> [DiscoveredEvent] {
        let query = URLComponents(string: initialURL)?.queryItems?.first(where: { $0.name == "query" })?.value
        var data = initialData
        var seenCursors = Set<String>()
        var results: [DiscoveredEvent] = []
        // Follow the source's cursor rather than imposing a ten-event list.
        // A byte limit and repeated-cursor check protect against broken servers.
        var totalBytes = 0
        while true {
            totalBytes += data.count
            guard totalBytes <= 20_000_000 else { throw CalendarError.tooLarge }
            results.append(contentsOf: try parseLumaPage(data, checkedAt: Date()))
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CalendarError.invalidResponse
            }
            guard let cursor = root["next_cursor"] as? String, !cursor.isEmpty else { break }
            guard seenCursors.insert(cursor).inserted else {
                print("ERROR: Luma repeated its pagination cursor")
                throw CalendarError.invalidResponse
            }
            data = try await download(lumaURL(query: query, cursor: cursor), accept: "application/json")
        }
        return results
    }

    static func parseLumaPage(_ data: Data, checkedAt: Date = Date()) throws -> [DiscoveredEvent] {
        guard data.count <= maximumBytes,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["entries"] as? [[String: Any]] else {
            throw CalendarError.invalidResponse
        }
        var events: [DiscoveredEvent] = []
        var ids = Set<String>()
        for entry in entries {
            guard let event = entry["event"] as? [String: Any], let name = event["name"] as? String,
                  isHackathonTitle(name) else { continue }
            guard let startText = event["start_at"] as? String, let endText = event["end_at"] as? String,
                  let start = isoDate(startText), let end = isoDate(endText), end >= start,
                  let slug = event["url"] as? String, !slug.isEmpty else {
                print("ERROR: Luma hackathon is missing exact date or event URL: \(name)")
                throw CalendarError.missingField("Luma date / event URL")
            }
            let website = "https://luma.com/\(slug)"
            guard isWebURL(website), ids.insert(website).inserted else { continue }
            let addressInfo = event["geo_address_info"] as? [String: Any] ?? [:]
            let coordinate = event["coordinate"] as? [String: Any]
            let attendance = event["location_type"] as? String ?? "offline"
            let format = attendance == "online" ? "Online" : attendance == "hybrid" ? "Hybrid" : "In person"
            guard format == "Online" || isBostonAddress(addressInfo, coordinate: coordinate) else { continue }

            let city = addressInfo["city_state"] as? String ?? addressInfo["city"] as? String ?? "Boston area"
            let isPublished = addressInfo["mode"] as? String == "shown" && event["geo_address_visibility"] as? String == "public"
            let address = isPublished ? addressInfo["full_address"] as? String ?? "" : ""
            let venueName = addressInfo["address"] as? String ?? city
            let venue = format == "Online" ? "Online · Boston community" : isPublished ? venueName : "\(city) · exact venue shared by organizer"
            let publishedCoordinate = isPublished ? coordinate : nil
            let latitude = publishedCoordinate?["latitude"] as? Double
            let longitude = publishedCoordinate?["longitude"] as? Double
            let ticket = entry["ticket_info"] as? [String: Any] ?? [:]
            let cost = ticket["is_free"] as? Bool == true ? "Free" : "Check ticket price on organizer page"
            let requiresApproval = ticket["require_approval"] as? Bool == true
            let availability = entry["registration_availability"] as? String ?? "unknown"
            let status: String
            if availability == "waitlist" || entry["waitlist_active"] as? Bool == true {
                status = "Waitlist available"
            } else if ticket["is_sold_out"] as? Bool == true {
                status = "Sold out · check organizer"
            } else if availability == "open" {
                status = requiresApproval ? "Registration open · host approval required" : "Registration open"
            } else {
                status = "Check organizer page"
            }
            let calendar = entry["calendar"] as? [String: Any]
            let calendarName = calendar?["name"] as? String ?? ""
            var hosts: [String] = []
            if let hostRecords = entry["hosts"] as? [[String: Any]] {
                for host in hostRecords {
                    if let hostName = host["name"] as? String, !hostName.isEmpty { hosts.append(hostName) }
                }
            }
            let organizer = !calendarName.isEmpty && calendarName != "Personal" ? calendarName : hosts.isEmpty ? "Organizer on Luma" : hosts.joined(separator: " · ")
            var notes = "Discovered from Luma’s public Boston event listings. Exact dates, published venue and ticket availability were refreshed from the live listing. Open the organizer page for the full agenda and eligibility."
            if !isPublished && format != "Online" {
                notes += " The organizer has not published a public street address; no exact map pin is shown."
            }
            events.append(DiscoveredEvent(
                id: website, name: name, organizer: organizer, startDate: start, endDate: end,
                schedule: try schedule(start: start, end: end, allDay: false), venue: venue,
                address: format == "Online" ? "" : address, cost: cost,
                eligibility: requiresApproval ? "Host approval required; check organizer requirements" : "Check organizer requirements",
                notes: notes, website: website, sourceURL: website, status: status, format: format,
                checkedAt: checkedAt, latitude: latitude, longitude: longitude
            ))
        }
        return events
    }

    static func parseHostedFeed(_ data: Data) throws -> [DiscoveredEvent] {
        guard data.count <= maximumBytes else { throw CalendarError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = isoDate(value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected an ISO 8601 date")
            }
            return date
        }
        let events = try decoder.decode([DiscoveredEvent].self, from: data)
        for event in events {
            guard !event.id.isEmpty, !event.name.isEmpty, event.endDate >= event.startDate,
                  isWebURL(event.website), isWebURL(event.sourceURL) else {
                throw CalendarError.invalidResponse
            }
            if let latitude = event.latitude, !(-90...90).contains(latitude) { throw CalendarError.invalidResponse }
            if let longitude = event.longitude, !(-180...180).contains(longitude) { throw CalendarError.invalidResponse }
        }
        return events
    }

    private static func isoDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let regular = ISO8601DateFormatter()
        return fractional.date(from: text) ?? regular.date(from: text)
    }

    private static func isHackathonTitle(_ title: String) -> Bool {
        let text = title.lowercased()
        let excluded = ["(archive)", "planning", "info session", "information session", "afterparty", "after party", "pre-drinks"]
        for word in excluded { if text.contains(word) { return false } }
        let included = ["hackathon", "hack-a-thon", "datathon", "buildathon", "hack night", "hack day", "build day", "game jam", "code jam"]
        for word in included { if text.contains(word) { return true } }
        return false
    }

    private static func isBostonAddress(_ address: [String: Any], coordinate: [String: Any]?) -> Bool {
        if let coordinate, let latitude = coordinate["latitude"] as? Double, let longitude = coordinate["longitude"] as? Double {
            return (42.0...42.8).contains(latitude) && (-71.6 ... -70.7).contains(longitude)
        }
        let country = address["country_code"] as? String ?? ""
        let region = address["region_short"] as? String ?? ""
        return country == "US" && region == "MA"
    }

    // Extra beyond the course: iCalendar parsing unfolds continued lines and
    // preserves source dates, including exclusive end dates for all-day events.
    static func parseCalendar(_ data: Data, checkedAt: Date = Date()) throws -> [DiscoveredEvent] {
        guard data.count <= maximumBytes else {
            print("ERROR: Organizer calendar exceeds \(maximumBytes) bytes")
            throw CalendarError.tooLarge
        }
        guard let text = String(data: data, encoding: .utf8), text.contains("BEGIN:VCALENDAR"),
              text.contains("END:VCALENDAR") else {
            print("ERROR: Organizer response is not a complete UTF-8 iCalendar")
            throw CalendarError.invalidCalendar
        }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []
        for line in normalized.components(separatedBy: "\n") {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")) && !lines.isEmpty {
                let previous = lines.removeLast()
                lines.append(previous + String(line.dropFirst()))
            } else {
                lines.append(line)
            }
        }
        var properties: [String: CalendarProperty] = [:]
        var isInEvent = false
        var results: [DiscoveredEvent] = []
        var ids = Set<String>()
        for line in lines {
            if line == "BEGIN:VEVENT" {
                guard !isInEvent else {
                    print("ERROR: Nested calendar event")
                    throw CalendarError.invalidCalendar
                }
                isInEvent = true
                properties = [:]
            } else if line == "END:VEVENT" {
                guard isInEvent else {
                    print("ERROR: Calendar event has no beginning")
                    throw CalendarError.invalidCalendar
                }
                if let event = try makeEvent(properties, checkedAt: checkedAt), ids.insert(event.id).inserted {
                    results.append(event)
                }
                isInEvent = false
            } else if isInEvent, let colon = line.firstIndex(of: ":") {
                let head = String(line[..<colon])
                let value = String(line[line.index(after: colon)...])
                let parts = head.components(separatedBy: ";")
                if let name = parts.first {
                    properties[name.uppercased()] = CalendarProperty(head: head, value: unescape(value))
                }
            }
        }
        guard !isInEvent else {
            print("ERROR: Calendar event has no ending")
            throw CalendarError.invalidCalendar
        }
        results.sort { first, second in
            if first.startDate == second.startDate {
                return first.id < second.id
            }
            return first.startDate < second.startDate
        }
        return results
    }

    private static func makeEvent(_ properties: [String: CalendarProperty], checkedAt: Date) throws -> DiscoveredEvent? {
        guard let title = properties["SUMMARY"]?.value else {
            print("ERROR: Organizer calendar event is missing SUMMARY")
            throw CalendarError.missingField("SUMMARY")
        }
        // This is a local organizer's calendar; unrelated talks are not hackathons.
        guard title.localizedCaseInsensitiveContains("hack") else {
            return nil
        }
        guard isBostonArea(properties) else {
            return nil
        }
        guard let startProperty = properties["DTSTART"], let endProperty = properties["DTEND"] else {
            print("ERROR: Organizer event is missing DTSTART or DTEND: \(title)")
            throw CalendarError.missingField("DTSTART / DTEND")
        }
        let start = try calendarDate(startProperty)
        let end = try calendarDate(endProperty)
        guard end >= start else {
            print("ERROR: Organizer event ends before it begins: \(title)")
            throw CalendarError.invalidDate(endProperty.value)
        }
        let description = properties["DESCRIPTION"]?.value ?? ""
        let website = eventWebsite(properties: properties, description: description)
        let uid = properties["UID"]?.value ?? ""
        guard !uid.isEmpty || website != organizerURLString else {
            print("ERROR: Organizer event has neither UID nor event URL: \(title)")
            throw CalendarError.missingField("UID / URL")
        }
        let id = website == organizerURLString ? "toa:\(uid)" : website
        let location = properties["LOCATION"]?.value ?? ""
        let locationIsLink = isWebURL(location)
        let publishedAddress = locationIsLink ? "" : location
        let lowerLocation = location.lowercased()
        let format: String
        if lowerLocation.contains("hybrid") {
            format = "Hybrid"
        } else if lowerLocation == "online" || lowerLocation == "virtual" || lowerLocation.contains("zoom.us/") {
            format = "Online"
        } else {
            format = "In person"
        }
        let status = properties["STATUS"]?.value.uppercased() == "CANCELLED" ? "Cancelled" : "Check organizer page"
        let organizer = organizerName(properties["ORGANIZER"]?.head)
        let coordinate = properties["GEO"]?.value.components(separatedBy: ";") ?? []
        let latitude = coordinate.count == 2 ? Double(coordinate[0]) : nil
        let longitude = coordinate.count == 2 ? Double(coordinate[1]) : nil
        return DiscoveredEvent(
            id: id, name: title, organizer: organizer, startDate: start, endDate: end,
            schedule: try schedule(start: start, end: end, allDay: isDateOnly(startProperty)),
            venue: publishedAddress.isEmpty ? "Location on organizer page" : publishedAddress,
            address: format == "Online" ? "" : publishedAddress,
            cost: "See organizer page", eligibility: "See organizer page",
            notes: description.isEmpty ? "Details are published by The Open Accelerator." : description,
            website: website, sourceURL: organizerURLString, status: status, format: format,
            checkedAt: checkedAt, latitude: latitude, longitude: longitude
        )
    }

    private static func calendarDate(_ property: CalendarProperty) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        guard let boston = TimeZone(identifier: "America/New_York") else {
            print("ERROR: Boston time zone is unavailable")
            throw CalendarError.invalidDate(property.value)
        }
        formatter.timeZone = boston
        if isDateOnly(property) {
            formatter.dateFormat = "yyyyMMdd"
        } else if property.value.hasSuffix("Z") {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = property.value.count == 14 ? "yyyyMMdd'T'HHmm'Z'" : "yyyyMMdd'T'HHmmss'Z'"
        } else {
            for parameter in property.head.components(separatedBy: ";") {
                if parameter.uppercased().hasPrefix("TZID=") {
                    let zoneName = String(parameter.dropFirst(5)).replacingOccurrences(of: "\"", with: "")
                    guard let zone = TimeZone(identifier: zoneName) else {
                        print("ERROR: Unsupported calendar time zone: \(zoneName)")
                        throw CalendarError.invalidDate(property.value)
                    }
                    formatter.timeZone = zone
                }
            }
            formatter.dateFormat = property.value.count == 13 ? "yyyyMMdd'T'HHmm" : "yyyyMMdd'T'HHmmss"
        }
        guard let date = formatter.date(from: property.value) else {
            print("ERROR: Cannot parse calendar date: \(property.value)")
            throw CalendarError.invalidDate(property.value)
        }
        return date
    }

    private static func schedule(start: Date, end: Date, allDay: Bool) throws -> String {
        guard let boston = TimeZone(identifier: "America/New_York") else {
            print("ERROR: Boston time zone is unavailable")
            throw CalendarError.invalidDate("America/New_York")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = boston
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = boston
        if allDay {
            // An iCalendar date-only DTEND is the first day outside the event.
            let lastDay: Date
            if end > start, let previous = calendar.date(byAdding: .day, value: -1, to: end) {
                lastDay = previous
            } else {
                lastDay = start
            }
            formatter.dateFormat = "MMM d, yyyy"
            let first = formatter.string(from: start)
            let last = formatter.string(from: lastDay)
            let dates = calendar.isDate(start, inSameDayAs: lastDay) ? first : "\(first) – \(last)"
            return "\(dates) · exact times on organizer page"
        }
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        let first = formatter.string(from: start)
        formatter.dateFormat = calendar.isDate(start, inSameDayAs: end) ? "h:mm a" : "MMM d, yyyy h:mm a"
        return "\(first) – \(formatter.string(from: end)) · Boston time"
    }

    private static func organizerName(_ head: String?) -> String {
        guard let head else {
            return "The Open Accelerator"
        }
        for parameter in head.components(separatedBy: ";") {
            if parameter.uppercased().hasPrefix("CN=") {
                let name = String(parameter.dropFirst(3)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return "The Open Accelerator · \(name)"
            }
        }
        return "The Open Accelerator"
    }

    private static func isDateOnly(_ property: CalendarProperty) -> Bool {
        return property.head.uppercased().components(separatedBy: ";").contains("VALUE=DATE")
    }

    private static func isBostonArea(_ properties: [String: CalendarProperty]) -> Bool {
        let location = properties["LOCATION"]?.value.lowercased() ?? ""
        // Explicit online events from this Boston organizer remain relevant.
        if location == "online" || location == "virtual" || location.contains("zoom.us/") {
            return true
        }
        if let geo = properties["GEO"]?.value {
            let parts = geo.components(separatedBy: ";")
            if parts.count == 2, let latitude = Double(parts[0]), let longitude = Double(parts[1]) {
                return (42.0...42.8).contains(latitude) && (-71.6 ... -70.7).contains(longitude)
            }
        }
        let cities = ["boston", "cambridge", "somerville", "brookline", "newton", "waltham",
                      "medford", "watertown", "quincy", "burlington", "needham", "dedham",
                      "framingham", "woburn", "everett", "malden", "chelsea", "revere",
                      "wellesley", "lexington", "arlington"]
        for city in cities {
            if location.contains(city) {
                return true
            }
        }
        // Unknown/hidden locations are not silently assumed to be in Boston.
        return false
    }

    private static func eventWebsite(properties: [String: CalendarProperty], description: String) -> String {
        if let website = properties["URL"]?.value, isWebURL(website) {
            return website
        }
        for word in description.components(separatedBy: .whitespacesAndNewlines) {
            if isWebURL(word) {
                return word
            }
        }
        if let location = properties["LOCATION"]?.value, isWebURL(location) {
            return location
        }
        return organizerURLString
    }

    private static func isWebURL(_ string: String) -> Bool {
        guard let url = URL(string: string), let host = url.host, !host.isEmpty,
              url.scheme?.lowercased() == "https", url.user == nil, url.password == nil else {
            return false
        }
        return true
    }

    private static func unescape(_ text: String) -> String {
        var output = ""
        var escaping = false
        for character in text {
            if escaping {
                if character == "n" || character == "N" {
                    output.append("\n")
                } else {
                    output.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                output.append(character)
            }
        }
        if escaping {
            output.append("\\")
        }
        return output
    }

    private struct CalendarProperty {
        var head: String
        var value: String
    }

    private enum CalendarError: LocalizedError {
        case invalidURL, invalidResponse, tooLarge, invalidCalendar, missingField(String), invalidDate(String), allSourcesFailed([String])
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "The organizer calendar URL is invalid."
            case .invalidResponse: return "The organizer calendar is temporarily unavailable."
            case .tooLarge: return "The organizer calendar exceeds the 2 MB limit."
            case .invalidCalendar: return "The organizer returned an invalid calendar."
            case .missingField(let field): return "The organizer calendar is missing \(field)."
            case .invalidDate(let value): return "The organizer published an unsupported date: \(value)."
            case .allSourcesFailed(let failures): return "All live sources are temporarily unavailable. " + failures.joined(separator: "; ")
            }
        }
    }
}
