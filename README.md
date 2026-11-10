# BOS / HACK — Boston Hackathons

An English-language iPhone app for real Greater Boston hackathons, date and topic filtering, registration reminders and native Apple maps with **🤖 event pins only**. SwiftUI and SwiftData retain the course’s model/List/NavigationLink foundation; networking, MapKit and Firebase are documented extensions.

**Firebase activation is pending. The real Firebase SDK and account screens compile, but the owner’s Firebase project has not been created because first-use terms require the owner’s acceptance. No real sign-in or cross-device saving is claimed as active. Guest browsing works.** See [Accounts/README.md](Accounts/README.md).

## Run the app

Open `BostonHacks.xcodeproj` in **Xcode 26+**, select the `BostonHacks` scheme and an **iOS 26+ iPhone Simulator**, then press **⌘R**. Xcode resolves the official Firebase iOS SDK, pinned to **12.19.3** in `Package.resolved`; Core, Auth and Firestore are linked. Analytics is not enabled by this app. Initial package resolution needs network access.

`bash scripts/build.sh` builds the unsigned generic iOS Simulator app. For a real iPhone, select your own Team in Signing & Capabilities and follow Xcode’s Developer Mode instructions. No signing credential, instructor Firebase configuration or administrator key is included. The owner’s `App/GoogleService-Info.plist` is intentionally absent and ignored by Git; account activation steps are in `Accounts/README.md`.

## Use it

- Swipe through three original illustrated welcome pages, using **Next**, **Skip** or **Explore Hackathons**. The next screen offers **Sign in**, **Create account** and **Continue as guest**. Missing cloud configuration is explained and account submissions are disabled. The app icon and static iOS launch image are separate from these interactive pages.
- On Home, choose a starting place and a date window. **START → END → Apply range** uses a two-step date/time picker; Cancel discards drafts. **Today** selects the current Boston calendar day. **One day** opens a calendar for any chosen day, covering midnight to the next midnight in Boston time.
- **Show Events** opens a separate **Hackathon results** screen using a real native `List`, one `ForEach` row per event and `NavigationLink` details. A theme button opens its results directly when dates are confirmed; otherwise it first opens date selection and navigates after Apply. Cancelling that picker does not navigate.
- Topic choices are **All**, **AI & Data**, **Health**, **Climate** and **Other**. Web3/blockchain belongs to AI & Data. Each event has one primary category using title-first keyword classification; a school name alone is not a topic. Results also offer day shortcuts within the current window.
- Availability is a separate reminder from the organizer action. **Full**, **Sold out**, closed and cancelled states receive a red reminder. An explicitly available waitlist gets a separate **Join waitlist** link. Unknown inventory does not become “registration open”; cost and eligibility links lead to the organizer for confirmation.
- **Explore these events on the map** shows only hackathon robots for the current window/topic. Tap a 🤖 for its details. Calendar edits the same result window. Online, hidden and unlocated events receive no guessed pin. The map contains no sightseeing overlay or starting-point marker.
- Choose a starting place using street/place autocomplete, US ZIP/ZIP+4 or optional **Use my location**. Known venue coordinates sort nearest first by straight-line distance; online/unknown-distance events follow. ZIP uses an area center, so distances are approximate, not travel times. **Open transit directions** opens native Apple Maps using `maps://`, your chosen start, the public venue address and public-transit mode. Apple Maps determines the route.
- Saving is designed for a real signed-in account; guests are directed to the account screen. After Firebase activation, profile → **My saved events** provides private saved listings across dates. There is no Saved-only toggle on the main results screen. Until activation, private account saves and cross-device synchronization remain unavailable.

All date calculations use **America/New_York**, including daylight saving transitions. Overlap filtering includes activities already in progress within the selected day/window. Unknown exact hours remain clearly marked even when all-day boundaries support filtering.

## Real data and ongoing updates

The bundled **11-event reviewed snapshot** provides offline starting data: seven overlap November 9–15, 2026, three overlap November 16–22, and the LinkedIn-discovered Spaulding event is January 22–24, 2027. Sources, eligibility, venue precision and unknown details are in `ResearchSources.md`; these are not fictional examples.

Direct live discovery checks Luma Boston public discovery/keyword pages and TOA’s organizer calendar, following pagination and deduplicating event identities. Checks run on launch, foreground return, manual refresh and every ten minutes while active. iOS suspension stops this foreground loop.

The separately deployed Python collector runs every **three hours**, subject to GitHub scheduling delays, checking seven source jobs across Luma, TOA, MIT and Northeastern. It publishes an app-compatible event array and a separate health report. Failed sources retain previous records and dates; complete failure preserves the existing feed.

- Repository: [SherryyyLin/BostonHacks](https://github.com/SherryyyLin/BostonHacks).
- Default public feed: [events.json](https://raw.githubusercontent.com/SherryyyLin/BostonHacks/main/Backend/feeds/events.json).
- Health: [status.json](https://raw.githubusercontent.com/SherryyyLin/BostonHacks/main/Backend/feeds/status.json).
- The [second successful run](https://github.com/SherryyyLin/BostonHacks/actions/runs/42737765265), November 9 at **8:43 PM Eastern**, passed **16 backend tests**, succeeded on **all seven sources** and published **17 deduplicated records**, including Spaulding. The public feed was read without authentication and decoded by the actual Swift hosted-feed parser. These are observed results, not a fixed future event count.

LinkedIn announcements are reviewed separately and About & Data provides a discovery link. The automated collector does **not** claim unattended LinkedIn scraping. A different real HTTPS feed can be configured under About & Data → Advanced feed settings. Backend setup and failure behavior are documented in `Backend/README.md`.

## Accounts, freshness and privacy

Public event records, venue-coordinate caches and feed settings use local SwiftData. Refresh merges by stable source identity, preserves detailed research dates and records separate live sightings. An older hosted record cannot replace a newer direct-source update. Disappearing from one response is not treated as cancellation.

The account implementation uses actual Firebase email/password APIs and private Firestore references at `users/{uid}/savedEvents/{SHA256(sourceID)}`. Its allowlisted payload is `sourceID`, `name`, `startDate` and server `updatedAt`; the provided rules restrict access to the authenticated owner and deny other collections. Private saved state clears on sign-out/account changes, and Firestore’s private cache is memory-only. **These cloud operations await the owner’s real project configuration and deployed rules.** They have not been verified against a live Firebase project.

The privacy manifest describes email address, display name, account UID and saved-event references for app functionality. Starting addresses, ZIP searches and optional GPS stay in the current session and are not uploaded to Firebase or event discovery feeds. Apple receives map search/address requests and any authorized one-shot location lookup. Opening directions shares the chosen start and destination with Apple Maps. Manual input and venue maps do not require device location access; denying optional location access keeps manual input usable.

## Files and learning guide

| File | Purpose |
|---|---|
| `App/BostonHacksApp.swift` | Welcome → account/guest → home, optional real Firebase setup, SwiftData container |
| `App/ContentView.swift` | Model, home date/topic flow, live updates, event details and transit link |
| `App/EventResultsView.swift` | Native List/ForEach/NavigationLink, day/topic filters and robot-map entry |
| `App/DateRangeSheet.swift`, `App/SingleDaySheet.swift` | Draft range and single-day calendar choices |
| `App/EventTopics.swift`, `App/EventStatusView.swift` | Four primary topics and separate availability/action presentation |
| `App/AccountStore.swift`, `App/AccountView.swift` | Real Auth/Firestore implementation, account forms and private saved references |
| `Accounts/` | Activation status, owner setup instructions and restrictive Firestore rules |
| `App/WelcomeView.swift`, `App/Assets.xcassets/`, `Artwork/` | Three welcome pages, app icon and original anime art |
| `App/Fonts/`, `DesignAssets.md` | Bundled Montserrat/OFL and asset generation record |
| `App/AddressSearchView.swift`, `App/EventDistance.swift` | Place/ZIP/one-shot location and nearest venue ordering |
| `App/HackathonMapView.swift` | Native map with event robot pins only |
| `App/LiveEventService.swift`, `App/verified-events.json` | Live parsers and reviewed seed records |
| `Backend/` | Independent Python collector, public feeds and 16 offline tests |
| `课堂代码说明.md`, `ResearchSources.md` | Classroom mapping, additional APIs and evidence limitations |

## Verification

The complete app built successfully for iOS Simulator using the actual Firebase SDK 12.19.3. **17 deterministic account-state tests use SDK adapters**, covering UID isolation, late callbacks, logout during writes, stable document keys, allowed payload fields and missing configuration; these are not live Firebase, emulator, two-device or UI tests. Backend tests are separate: `python3 -m unittest discover -s Backend/tests -v` runs 16 offline tests. See `Accounts/README.md` for post-activation checks.

For a manual demo: traverse all welcome pages, browse as guest, apply/cancel date drafts, try Today and One day, tap a theme and compare results, open a robot’s details, inspect Full/Join waitlist distinctions and launch native transit directions. Confirm a failed refresh retains public listings. Once the owner activates Firebase, separately test sign-up/sign-in/reset, two-account isolation and same-account cross-device saves.

The cool Morandi palette, glass actions, Montserrat and three-person anime illustrations affect presentation; organizer evidence still determines dates, eligibility and admission.
