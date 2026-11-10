# Accounts and private saved events

The account implementation follows Prof. Gallaugher's Firebase email/password and Firestore pattern, extended to isolate private saved events by authenticated UID.

- `AccountStore.swift` performs real Firebase Authentication calls and listens to `users/{uid}/savedEvents`.
- Firebase iOS SDK 12.19.3 is resolved and pinned. Core, Authentication and Firestore are linked; Analytics is not enabled by this app.
- `AccountView.swift` provides sign-up, sign-in, reset-password, profile and sign-out screens. Guest browsing remains available.
- The app never represents a local account selector as authentication. Missing Firebase configuration is shown honestly and account operations remain unavailable.
- Private favorites are cleared immediately on logout or account switching. Listener and write callbacks from a prior account cannot populate the next account. Private Firestore cache is memory-only.
- Starting addresses, ZIP queries and GPS coordinates stay in the current app session and are not saved in Firebase.

## Current activation status

The owner's new Firebase project is **not created yet**. Its creation form is prepared with the display name BostonHacks, but the owner must read and accept the first-use Firebase terms. No Firebase terms were accepted by the assistant, and no billing or Analytics was enabled.

Until setup is complete, the app presents the real account screens and lets people browse as guests; actual sign-in and cross-device synchronization cannot be tested or claimed as active.

## Complete Firebase setup

1. The project owner accepts Firebase's terms and creates the project on the free plan, with Analytics disabled.
2. Register an iOS app with bundle ID `com.example.BOSHacks`.
3. Download that app's `GoogleService-Info.plist` into `App/`. This project ignores the local configuration file in Git; use the owner's real project, never the instructor's example project.
4. Enable Email/Password under Authentication → Sign-in method.
5. Create Cloud Firestore in production mode. Publish `Accounts/firestore.rules` before using the client. The rules restrict reads and writes to the matching authenticated UID, constrain the saved-reference fields, and deny other collections.
6. Build and run again. The app configures Firebase only if its own configuration file is present.

With the Firebase CLI authenticated to the correct owner/project, rules can also be deployed from the project root:

```sh
firebase deploy --only firestore:rules --project YOUR_PROJECT_ID
```

This is a setup command, not a claim that a project or rules deployment has already happened.

## Validation boundaries

The actual SDK integration compiles. Seventeen deterministic account-state tests passed using SDK adapters, covering UID isolation, late callbacks, logout during writes, stable document keys, allowed payload fields and missing configuration. These do not replace a real two-account/two-device test against the owner's Firebase project.

After activation, verify that account A's saved event appears on another device signed in as A, disappears after sign-out, and cannot be read by account B. Confirm denied database requests for another UID and no public writes.

## Teacher references

- [Course overview video](https://www.youtube.com/watch?v=L0flpU1ClrQ) — title/description and playback metadata were available; the spoken video was not transcribed.
- [Teacher's Snacktacular25 source](https://github.com/gallaugher/Snacktacular25) — Firebase Authentication, Firestore, SwiftUI NavigationStack, List and NavigationLink.

