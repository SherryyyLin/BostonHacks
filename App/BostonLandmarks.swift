import Foundation
import MapKit

// Public landmarks are separate from event records. Addresses come from the City
// of Boston, the artist's site, and the official Freedom Trail Foundation pages.
// Apple Maps resolves their locations; we never draw an invented walking route.
struct BostonLandmark: Identifiable {
    let id: String
    let name: String
    let address: String
    let symbol: String
    let subtitle: String
    let website: URL?

    static let sights: [BostonLandmark] = [
        BostonLandmark(id: "ducklings", name: "Make Way for Ducklings", address: "Make Way for Ducklings, Boston Public Garden, Beacon Street and Charles Street, Boston, MA",
                       symbol: "🦆", subtitle: "Nancy Schön's duckling sculptures in the Public Garden. A little Boston detour between builds.",
                       website: URL(string: "https://www.schon.com/public/ducklings-boston.php")),
        BostonLandmark(id: "boston-common", name: "Boston Common", address: "139 Tremont Street, Boston, MA 02111",
                       symbol: "🧱", subtitle: "Freedom Trail highlight · The visitor information center marks the start of the trail.",
                       website: URL(string: "https://www.thefreedomtrail.org/trail-sites/boston-common")),
        BostonLandmark(id: "state-house", name: "Massachusetts State House", address: "24 Beacon Street, Boston, MA 02108",
                       symbol: "🏛️", subtitle: "Freedom Trail highlight · The gold-domed State House beside Boston Common.",
                       website: URL(string: "https://www.thefreedomtrail.org/trail-sites/massachusetts-state-house")),
        BostonLandmark(id: "faneuil-hall", name: "Faneuil Hall", address: "1 Faneuil Hall Square, Boston, MA 02109",
                       symbol: "🧱", subtitle: "Freedom Trail highlight · A historic meeting hall and marketplace in the heart of the city.",
                       website: URL(string: "https://www.thefreedomtrail.org/trail-sites/faneuil-hall")),
        BostonLandmark(id: "old-north", name: "Old North Church", address: "193 Salem Street, Boston, MA 02113",
                       symbol: "⛪", subtitle: "Freedom Trail highlight · Boston's oldest surviving church building in the North End.",
                       website: URL(string: "https://www.thefreedomtrail.org/trail-sites/old-north-church")),
        BostonLandmark(id: "mit-museum", name: "MIT Museum · Pink Chicken Project", address: "314 Main Street, Cambridge, MA 02142",
                       symbol: "🐔", subtitle: "Pink Chicken Project appeared in Gene Cultures (2022–24). Check current museum displays.",
                       website: URL(string: "https://mitmuseum.mit.edu/"))
    ]
}

struct BostonLandmarkPin: Identifiable {
    let landmark: BostonLandmark
    let coordinate: CLLocationCoordinate2D
    var id: String { landmark.id }
}
