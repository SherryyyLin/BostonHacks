# BOS / HACK — Boston Hackathons

An English-language iPhone app for discovering real Greater Boston hackathons, choosing a start/end date and time, checking registration status and exploring venues on a native Apple map with **🤖 robot pins**. SwiftUI and SwiftData retain the course’s model/list/detail foundation; live discovery, MapKit and the optional scheduled backend are explicitly documented extensions.

## Run the app

Open `BostonHacks.xcodeproj` in **Xcode 26+**, select the `BostonHacks` scheme and an **iPhone Simulator with iOS 26+**, then press **⌘R**. For a real iPhone, select your own Team under **Signing & Capabilities**, choose a unique Bundle Identifier if needed and follow Xcode’s Developer Mode instructions. No certificate or account credential is included.

From this project directory, `bash scripts/build.sh` builds the unsigned generic iOS Simulator app without launching it. The iOS 26 minimum supports the course’s `.glassProminent` buttons and the current MapKit geocoding API.

## Use it

- Swipe through three illustrated welcome pages: teammates, calendar and map. Use **Next**, **Skip**, or **Explore Hackathons** on the last page; no account is required. The app also includes its own app icon and a static iOS launch image. The launch image is distinct from the three interactive welcome pages.
- The home screen starts with your starting point and date selection. Tap **START** or **END** to open a two-step date/time picker: choose START, continue to END, then **Apply range**. Both endpoints remain visible; Cancel discards drafts. **Show Events** becomes available after applying a range and opens a separate **Hackathon results** screen with a native List and one row per event. The results and map use events overlapping that window in **America/New_York** time.
- New events are discovered from **Luma’s public Boston event discovery/search pages and TOA’s public calendar**. The app checks on launch, on returning to the foreground, every ten minutes while active, and when using the refresh icon or pull-to-refresh. It follows pagination and deduplicates source URLs; it is not limited to the bundled records.
- Registration status is a **clickable link** in the list and detail screen. Waitlisted, sold-out, closed and approval-required listings keep their distinct states. Unknown cost and eligibility provide links to check the organizer. A status link never guarantees admission.
- **Explore these events on the map** opens the native Apple map for the chosen date/time range and saved filter. Tap a **🤖** to open that event’s details. The map’s Calendar action edits the same date/time range, and a separate blue marker shows a chosen starting point. Only published venue coordinates or successfully resolved public venue addresses receive pins; online, hidden and unknown locations are omitted.
- Turn on **Boston sights** in the map to see separate landmark pins, including the Public Garden ducklings, selected Freedom Trail stops and MIT Museum. These are places to explore, not hackathons. The museum’s Pink Chicken Project is documented as a past Gene Cultures exhibition; check current displays before visiting for that artwork.
- **Save event** stores a bookmark locally. Saved events only applies to the selected date/time range.
- Choose a starting point by place/street address autocomplete, a five-digit US ZIP/ZIP+4 search, or the optional **Use my location** button. Manual search remains available without location access. Use **Open transit directions** in an event detail; Apple Maps handles the route. A ZIP search uses the area center, so the route is approximate. Starting-point input lasts for this session. Events with confirmed venue coordinates are ordered nearest first using straight-line distance, including from a ZIP center; online and unknown-distance events follow known physical venues. The distance is not travel time.

The initial **11-event reviewed snapshot** provides offline starting data. See `ResearchSources.md` for dates, eligibility and evidence limitations. The snapshot includes seven events overlapping November 9–15, 2026 and three overlapping November 16–22, plus the LinkedIn-discovered Spaulding event on January 22–24, 2027; live sources add more. Activity dates, availability and venue precision can change.

## Updates while the app is closed

The app cannot keep running continuously after iOS suspends it. **A separate scheduled collector is included** for ongoing collection outside the app:

1. Follow `Backend/README.md` to place the project or feed-only files in a repository you control and enable `.github/workflows/update-events.yml`.
2. The workflow collects every **three hours** and publishes an app-compatible `Backend/feeds/events.json`, plus `status.json` for source health.
3. The deployed feed URL is already the app default. To use another collector, enter its direct HTTPS JSON URL under **About & Data → Advanced feed settings** and tap **Save and refresh**. The setting persists in SwiftData.

**Deployed:** [SherryyyLin/BostonHacks](https://github.com/SherryyyLin/BostonHacks). The first [collector run](https://github.com/SherryyyLin/BostonHacks/actions/runs/42716474929) succeeded on November 9, 2026 at 5:58 PM Eastern: 15 tests passed, all seven source jobs succeeded and 16 records were published. The three-hour schedule is enabled on `main`; GitHub can delay queued jobs. Use `https://raw.githubusercontent.com/SherryyyLin/BostonHacks/main/Backend/feeds/events.json` for the live feed. Future runs may differ.

The backend uses Luma Boston discovery/keyword pagination, TOA, and verified MIT/Northeastern public calendar APIs. It can discover new records as sources publish them; it does not merely regenerate the reviewed snapshot. Failed sources retain their prior data and verification dates. If every source fails, the existing event feed is preserved. Public source coverage remains incomplete, so consult organizers before planning travel.

## Freshness and privacy

Events, bookmarks, feed settings and cached public venue coordinates use local SwiftData. Refresh merges by stable source identity and preserves bookmarks; partial source failures retain stored listings. Absence from one response does not prove cancellation, so removed records are not automatically deleted from the app. Detailed research keeps its original verification date, while live sightings have a separate check timestamp and reliable availability updates can change status. The newest source timestamp wins, so an older hosted feed cannot replace a fresher direct-source update.

Manual search and event pins do not require device location permission. **Use my location** first explains the sharing, then requests one location fix only after the user continues and grants iOS permission; denying permission keeps manual search available. Apple receives search text, public venue addresses and any authorized location lookup. Opening directions passes the chosen starting point and destination to Apple Maps. The starting address is not sent to event discovery feeds. External pages, map services and live updates require network access; stored event details can be read offline. Source providers receive ordinary request information.

A map location without a published street address is not guessed. No pin is created from an obfuscated Luma coordinate. Unknown event hours are shown as uncertain even though full-day boundaries may be stored for week filtering. Broader Greater Boston venues are labeled Cambridge, Medford, Chestnut Hill or Wellesley as applicable.

## Files and learning guide

| File | Purpose |
|---|---|
| `App/BostonHacksApp.swift` | English locale, Boston time zone and SwiftData model container |
| `App/ContentView.swift` | Model, home search flow, date selection, status links, refresh and saved settings |
| `App/EventResultsView.swift` | Native List and system navigation title, filtered results, nearest ordering, favorites and map entry |
| `App/WelcomeView.swift` | Three illustrated swipeable welcome pages, Next/Skip and Explore Hackathons |
| `App/Assets.xcassets/` | App icon and three original illustrated onboarding assets |
| `Config/Info.plist` | Static iOS launch image configuration and optional location permission description |
| `App/Fonts/` | Official Montserrat font and its SIL Open Font License |
| `App/DateRangeSheet.swift` | Two-step START/END date and time drafts, validation and Apply/Cancel |
| `App/AddressSearchView.swift` | Place autocomplete, ZIP lookup and optional one-shot location |
| `App/EventDistance.swift` | Straight-line distance, nearest-first ordering and public venue coordinate resolution |
| `App/HackathonMapView.swift` | Native Apple map, robot annotations and public venue geocoding |
| `App/BostonLandmarks.swift` | Separate Boston sights with source links and published addresses |
| `App/LiveEventService.swift` | Public network sources, pagination, iCalendar/JSON parsing and hosted-feed validation |
| `App/verified-events.json` | Researched starting snapshot with original sources |
| `Backend/` | Standard-library Python collector, generated feed, source-health report and offline tests |
| `课堂代码说明.md` | Chinese explanation of classroom patterns and additional APIs |
| `ResearchSources.md` | Event evidence and live-source limitations |

Backend verification: `python3 -m unittest discover -s Backend/tests -v` runs 16 tests without network. The implementation also has separate Swift parser/date checks exercised during development; no claim is made that these are Xcode UI tests.

## Manual checks

1. Swipe all three welcome pages and try Next/Skip. On the home screen, apply START and END date/time, then tap Show Events. The results and map should show the same overlapping activities. Cancel an edit and confirm both values stay unchanged. An empty range shows an honest empty state.
2. Refresh online; confirm new source listings and distinct registration states. Disconnect and refresh again; stored activities should remain with a failure message.
3. Open the native map; tap a robot to see its event. Toggle Boston sights and confirm their pins are distinct from robots. Online/hidden-location events should not receive a guessed pin. Unavailable geocoding should show a message and keep the list usable.
4. Follow a status, cost or eligibility link; returning from the organizer page should not alter bookmarks.
5. Save an event and relaunch; its bookmark should remain. Try place autocomplete and ZIP search. Decline optional location sharing: manual input should still work. The chosen start should be passed to Maps; a blank start disables directions.
6. The default hosted feed is connected; another hosted feed works only after its real endpoint is configured. An invalid feed or failed collector source must not clear existing activities.

The interface uses cool Morandi blues, translucent glass actions, restrained gradients and the bundled Montserrat typeface. Original anime illustrations show three teammates and Boston scenery; these are presentation choices, separate from source verification and admission status. See `DesignAssets.md` for the asset record.

Technical source reports and feed settings live in **About & Data**; the home footer keeps a short update message. Luma registration links request English using the verified `locale=en` parameter; organizer-written content and other external apps can still follow their own language preferences. The app does not change device or account language settings.

LinkedIn public announcements are reviewed separately: the Spaulding rehabilitation hackathon was added from the official MIT Hacking Medicine announcement with unknown details stated explicitly. **About & Data** includes a LinkedIn discovery link. The automated collector currently checks its seven Luma, TOA and university jobs; it does not claim unattended LinkedIn scraping.
