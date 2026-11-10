import Foundation
import Combine
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// Beyond the classroom's on-device SwiftData: Firebase Auth identifies a real
// account, and Firestore keeps only that account's saved-event references.
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var user: FirebaseAuth.User?
    @Published private(set) var savedIDs: Set<String> = []
    @Published private(set) var isWorking = false
    @Published private(set) var savingIDs: Set<String> = []
    @Published private(set) var isSyncingSaved = false
    @Published var errorMessage: String?

    private var auth: Auth?
    private var database: Firestore?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var savedListener: ListenerRegistration?
    private var listeningUID: String?
    private var generation = 0

    var isConfigured: Bool {
        return FirebaseApp.app() != nil
    }

    init() {
        _ = configureIfNeeded(reportError: false)
    }

    deinit {
        savedListener?.remove()
        if let authListener {
            auth?.removeStateDidChangeListener(authListener)
        }
    }

    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        guard !isWorking, configureIfNeeded(), let auth else { return false }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and password."
            return false
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await auth.signIn(withEmail: cleanEmail, password: password)
            acceptAuthState(result.user)
            return true
        } catch {
            errorMessage = "Could not sign in. \(error.localizedDescription)"
            print("ERROR: Firebase sign-in failed (code \((error as NSError).code)).")
            return false
        }
    }

    @discardableResult
    func signUp(email: String, password: String, displayName: String) async -> Bool {
        guard !isWorking, configureIfNeeded(), let auth else { return false }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, password.count >= 6, !cleanName.isEmpty else {
            errorMessage = "Enter your name, email, and a password with at least 6 characters."
            return false
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await auth.createUser(withEmail: cleanEmail, password: password)
            acceptAuthState(result.user)
            let change = result.user.createProfileChangeRequest()
            change.displayName = cleanName
            do {
                try await change.commitChanges()
                // Publish the refreshed profile without replacing the UID's listener.
                acceptAuthState(auth.currentUser)
            } catch {
                errorMessage = "Your account was created, but your display name could not be saved. You can still sign in."
                print("ERROR: Firebase display-name update failed (code \((error as NSError).code)).")
            }
            return true
        } catch {
            errorMessage = "Could not create your account. \(error.localizedDescription)"
            print("ERROR: Firebase sign-up failed (code \((error as NSError).code)).")
            return false
        }
    }

    @discardableResult
    func resetPassword(email: String) async -> Bool {
        guard !isWorking, configureIfNeeded(), let auth else { return false }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            errorMessage = "Enter your email address first."
            return false
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await auth.sendPasswordReset(withEmail: cleanEmail)
            return true
        } catch {
            errorMessage = "Could not send a password reset. \(error.localizedDescription)"
            print("ERROR: Firebase password-reset request failed (code \((error as NSError).code)).")
            return false
        }
    }

    @discardableResult
    func signOut() -> Bool {
        guard !isWorking, configureIfNeeded(), let auth else { return false }
        errorMessage = nil
        // Clear personal data immediately, before any queued old listener fires.
        clearSavedState()
        user = nil
        do {
            try auth.signOut()
            return true
        } catch {
            // Sign-out failed, so restore only the still-authenticated account.
            acceptAuthState(auth.currentUser)
            errorMessage = "Could not sign out. Please try again."
            print("ERROR: Firebase sign-out failed (code \((error as NSError).code)).")
            return false
        }
    }

    func isSaved(_ event: Hackathon) -> Bool {
        return user != nil && savedIDs.contains(event.sourceID)
    }

    @discardableResult
    func toggleSaved(_ event: Hackathon) async -> Bool {
        guard configureIfNeeded(), let auth, let database else { return false }
        guard let uid = user?.uid, auth.currentUser?.uid == uid else {
            errorMessage = "Sign in to save events and sync them across your devices."
            return false
        }
        let sourceID = event.sourceID
        guard !sourceID.isEmpty else {
            errorMessage = "This event has no stable source identifier."
            print("ERROR: Cannot save an event without a source identifier.")
            return false
        }
        guard !savingIDs.contains(sourceID) else { return false }
        let requestGeneration = generation
        let wasSaved = savedIDs.contains(sourceID)
        let name = event.name
        let startDate = event.startDate
        let reference = database.collection("users").document(uid)
            .collection("savedEvents").document(Self.documentKey(for: sourceID))
        savingIDs.insert(sourceID)
        errorMessage = nil
        defer {
            if requestGeneration == generation && user?.uid == uid {
                savingIDs.remove(sourceID)
            }
        }
        do {
            if wasSaved {
                try await reference.delete()
            } else {
                try await reference.setData([
                    "sourceID": sourceID,
                    "name": name,
                    "startDate": startDate,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
            guard requestGeneration == generation, user?.uid == uid, auth.currentUser?.uid == uid else {
                return false
            }
            // Async Firestore completion means the server accepted this write.
            // The listener also receives changes made on another signed-in device.
            if wasSaved { savedIDs.remove(sourceID) }
            else { savedIDs.insert(sourceID) }
            return true
        } catch {
            guard requestGeneration == generation, user?.uid == uid, auth.currentUser?.uid == uid else {
                return false
            }
            errorMessage = "Could not update your saved events. \(error.localizedDescription)"
            print("ERROR: Firebase saved-event update failed (code \((error as NSError).code)).")
            return false
        }
    }

    // URLs contain slashes, so use a stable SHA-256 key for a single document.
    nonisolated static func documentKey(for sourceID: String) -> String {
        let digest = SHA256.hash(data: Data(sourceID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    private func configureIfNeeded(reportError: Bool = true) -> Bool {
        guard FirebaseApp.app() != nil else {
            if reportError {
                errorMessage = "Accounts are not connected yet. Add this app's Firebase configuration to enable real sign-in and cross-device saves."
                print("ERROR: Firebase is not configured; no account operation was attempted.")
            }
            return false
        }
        if auth != nil && database != nil { return true }
        let configuredAuth = Auth.auth()
        let configuredDatabase = Firestore.firestore()
        let settings = configuredDatabase.settings
        // Avoid persisting private favorites for a later person on this device.
        settings.cacheSettings = MemoryCacheSettings()
        configuredDatabase.settings = settings
        auth = configuredAuth
        database = configuredDatabase
        authListener = configuredAuth.addStateDidChangeListener { [weak self] _, updatedUser in
            Task { @MainActor [weak self] in self?.acceptAuthState(updatedUser) }
        }
        acceptAuthState(configuredAuth.currentUser)
        return true
    }

    private func acceptAuthState(_ updatedUser: FirebaseAuth.User?) {
        // An old callback must not re-open the account that has just signed out.
        guard updatedUser?.uid == auth?.currentUser?.uid else { return }
        let uid = updatedUser?.uid
        if listeningUID == uid && user?.uid == uid {
            user = updatedUser
            return
        }
        clearSavedState()
        user = updatedUser
        errorMessage = nil
        guard let uid, let database else { return }
        listeningUID = uid
        isSyncingSaved = true
        let listenerGeneration = generation
        savedListener = database.collection("users").document(uid).collection("savedEvents")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == listenerGeneration,
                          self.user?.uid == uid, self.auth?.currentUser?.uid == uid else { return }
                    if let error {
                        self.isSyncingSaved = false
                        self.errorMessage = "Saved events could not sync. \(error.localizedDescription)"
                        print("ERROR: Firebase saved-event listener failed (code \((error as NSError).code)).")
                        return
                    }
                    guard let snapshot else {
                        self.isSyncingSaved = false
                        self.errorMessage = "Saved events could not sync. Please reconnect and try again."
                        print("ERROR: Firebase saved-event listener returned no snapshot.")
                        return
                    }
                    // Wait for acknowledgement instead of presenting a queued
                    // offline mutation as a completed cross-device save.
                    guard !snapshot.metadata.hasPendingWrites else { return }
                    var ids = Set<String>()
                    for document in snapshot.documents {
                        if let sourceID = document.data()["sourceID"] as? String, !sourceID.isEmpty {
                            ids.insert(sourceID)
                        }
                    }
                    self.savedIDs = ids
                    self.isSyncingSaved = snapshot.metadata.isFromCache
                }
            }
    }

    private func clearSavedState() {
        generation += 1
        savedListener?.remove()
        savedListener = nil
        listeningUID = nil
        savedIDs = []
        savingIDs = []
        isSyncingSaved = false
    }
}
