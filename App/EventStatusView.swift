import SwiftUI

// Availability is a reminder; the separate link opens the organizer's action.
// A public listing alone never means that registration is still open.
struct EventStatusView: View {
    let event: Hackathon

    private let reminder = Color(.sRGB, red: 164.0 / 255, green: 76.0 / 255, blue: 98.0 / 255, opacity: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statusLabel)
                .font(.custom("Montserrat-SemiBold", size: 12))
                .foregroundStyle(needsReminder ? reminder : AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let url = webURL(event.website) {
                Link(destination: url) {
                    Label(actionLabel, systemImage: "arrow.up.right")
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent).tint(AppPalette.ink)
                .accessibilityLabel("\(actionLabel) for \(event.name)")
            } else {
                Text("Event link unavailable. Check the organizer's official site.")
                    .font(.custom("Montserrat-Regular", size: 11))
                    .foregroundStyle(AppPalette.ink.opacity(0.75))
            }
        }
    }

    private var normalizedStatus: String {
        event.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var cancelled: Bool {
        normalizedStatus.contains("cancelled") || normalizedStatus.contains("canceled")
    }

    private var full: Bool {
        normalizedStatus.contains("full") || normalizedStatus.contains("sold out")
    }

    private var closed: Bool {
        normalizedStatus.contains("closed") ||
            (normalizedStatus.contains("deadline") && normalizedStatus.contains("passed"))
    }

    private var waitlistAvailable: Bool {
        normalizedStatus.contains("waitlist") &&
            !normalizedStatus.contains("no waitlist") &&
            !normalizedStatus.contains("waitlist unavailable") &&
            !normalizedStatus.contains("waitlist closed")
    }

    private var needsReminder: Bool { cancelled || full || closed }

    private var statusLabel: String {
        if cancelled { return "Event cancelled" }
        if full { return normalizedStatus.contains("sold out") ? "Sold out" : "Full" }
        if closed {
            if normalizedStatus.contains("deadline") { return "Registration deadline passed" }
            return normalizedStatus.contains("applications") ? "Applications closed" : "Registration closed"
        }
        return event.status.isEmpty ? "Check organizer for availability" : event.status
    }

    private var actionLabel: String {
        if cancelled { return "View organizer page" }
        if full { return waitlistAvailable ? "Join waitlist" : "View organizer page" }
        if closed { return "View event details" }
        if waitlistAvailable { return "Join waitlist" }
        return "Register / event details"
    }
}
