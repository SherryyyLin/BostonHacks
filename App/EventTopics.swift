import Foundation

// Each event has one primary topic. A school name is not an event topic.
enum EventTopic {
    static let names = ["AI & Data", "Health", "Climate", "Other"]

    static func category(for event: Hackathon) -> String {
        return category(name: event.name, organizer: event.organizer, notes: event.notes)
    }

    static func category(name: String, organizer: String = "", notes: String = "") -> String {
        // The BC event concerns spiritual practices, even though its description
        // also mentions technology and a research study.
        if name.localizedCaseInsensitiveContains("spiritual") { return "Other" }
        if let topic = topic(in: name) { return topic }
        if let topic = topic(in: organizer + " " + notes) { return topic }
        return "Other"
    }

    private static func topic(in text: String) -> String? {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        let normalized = " " + words.joined(separator: " ") + " "
        let climate = ["climate", "sustainab", "environment", "green fund", "clean energy"]
        let health = ["health", "medical", "medicine", "oncology", "biosecurity", "rehab", "biology", "biotech", "openbio", " bio "]
        let technology = [" ai ", " data ", "artificial intelligence", "machine learning", "datathon", "agent",
                          "blockchain", "web3", "crypto", "ethereum", "solana", "bitcoin", "digital",
                          "coding", " code ", "software", " saas ", " build ", "buildathon"]
        for keyword in climate { if normalized.contains(keyword) { return "Climate" } }
        for keyword in health { if normalized.contains(keyword) { return "Health" } }
        for keyword in technology { if normalized.contains(keyword) { return "AI & Data" } }
        return nil
    }
}
