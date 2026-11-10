import SwiftUI

// The teacher's Firebase email/password pattern, with private per-user saved events.
struct AccountView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    var onContinueAsGuest: (() -> Void)? = nil
    @State private var createAccount = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var notice = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image("LaunchTeam").resizable().scaledToFill()
                        .frame(height: 190).clipped().clipShape(RoundedRectangle(cornerRadius: 24))
                        .accessibilityHidden(true)
                    if let user = account.user {
                        Text("Your Boston chapter.").font(.custom("Montserrat-Bold", size: 28))
                        Text(user.displayName ?? "Hackathon builder").font(.custom("Montserrat-SemiBold", size: 18))
                        Text(user.email ?? "").font(.custom("Montserrat-Regular", size: 14))
                        Label("\(account.savedIDs.count) saved events synced to your account", systemImage: "bookmark.fill")
                            .font(.custom("Montserrat-Regular", size: 13))
                        NavigationLink {
                            EventResultsView(startDate: .distantPast, endDate: .distantFuture, departureAddress: "",
                                             startingLatitude: nil, startingLongitude: nil, savedOnly: true)
                        } label: {
                            Label("My saved events", systemImage: "bookmark.fill").foregroundStyle(.white)
                                .font(.custom("Montserrat-SemiBold", size: 13))
                        }.buttonStyle(.glassProminent).tint(AppPalette.ink)
                        Text("Sign in with this account on another device to see the same saved events. Your starting address and location stay in this session.")
                            .font(.custom("Montserrat-Regular", size: 12)).lineSpacing(4)
                        Button { if account.signOut() { dismiss() } } label: {
                            Text("Sign out").foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 7)
                        }.buttonStyle(.glassProminent).tint(AppPalette.ink)
                        if account.isSyncingSaved { ProgressView("Syncing saved events…") }
                    } else {
                        Text(createAccount ? "Start your next\nchapter." : "Welcome back.")
                            .font(.custom("Montserrat-Bold", size: 30))
                        Text("Your account. Your saved hackathons. Any device.")
                            .font(.custom("Montserrat-Regular", size: 13)).foregroundStyle(AppPalette.secondary)
                        HStack(spacing: 12) {
                            modeButton("Sign in", isCreate: false)
                            modeButton("Create account", isCreate: true)
                        }
                        if !account.isConfigured {
                            Label("Cloud sign-in is being connected. You can explore as a guest while setup finishes.", systemImage: "info.circle")
                                .font(.custom("Montserrat-Regular", size: 12)).lineSpacing(3)
                                .padding(14).background(AppPalette.lavender.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            if createAccount {
                                fieldLabel("NAME")
                                TextField("Your name", text: $name).textContentType(.name)
                            }
                            fieldLabel("EMAIL")
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress).textContentType(.username)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            fieldLabel("PASSWORD")
                            SecureField(createAccount ? "At least 6 characters" : "Your password", text: $password)
                                .textContentType(createAccount ? .newPassword : .password)
                            if createAccount {
                                fieldLabel("CONFIRM PASSWORD")
                                SecureField("Repeat your password", text: $confirmation).textContentType(.newPassword)
                            }
                        }.textFieldStyle(.roundedBorder).font(.custom("Montserrat-Regular", size: 14))
                        if let error = account.errorMessage {
                            Text(error).font(.custom("Montserrat-Regular", size: 12)).foregroundStyle(AppPalette.pinkInk)
                        }
                        if !notice.isEmpty { Text(notice).font(.custom("Montserrat-Regular", size: 12)) }
                        Button { submit() } label: {
                            HStack {
                                if account.isWorking { ProgressView().tint(.white) }
                                Text(createAccount ? "Create account" : "Sign in")
                                    .font(.custom("Montserrat-SemiBold", size: 15))
                            }.foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent).tint(AppPalette.ink)
                        .disabled(!account.isConfigured || account.isWorking || email.isEmpty || password.isEmpty)
                        .accessibilityIdentifier("submit-account")
                        if !createAccount {
                            Button {
                                Task {
                                    if await account.resetPassword(email: email) {
                                        notice = "If an account exists for this address, check your email for reset instructions."
                                    }
                                }
                            } label: { Text("Forgot password?").foregroundStyle(AppPalette.ink) }
                                .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                                .disabled(!account.isConfigured || email.isEmpty || account.isWorking)
                        }
                        Button {
                            if let onContinueAsGuest { onContinueAsGuest() }
                            else { dismiss() }
                        } label: { Text("Continue as guest").foregroundStyle(AppPalette.ink).frame(maxWidth: .infinity) }
                            .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                        Text("Browsing is open to everyone. Sign in to save and sync favorites. Email and saved-event references are stored in your private Firebase account; addresses and GPS are not uploaded to the event feed.")
                            .font(.custom("Montserrat-Regular", size: 10)).foregroundStyle(AppPalette.secondary).lineSpacing(4)
                    }
                }.foregroundStyle(AppPalette.ink).padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(AppPalette.backgroundGradient)
                .navigationTitle(account.user == nil ? "Your account" : "Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { if onContinueAsGuest == nil { Button("Done") { dismiss() }.buttonStyle(.glassProminent).tint(AppPalette.frostBlue) } }
        }
    }

    func modeButton(_ title: String, isCreate: Bool) -> some View {
        return Button {
            createAccount = isCreate
            notice = ""
            account.errorMessage = nil
        } label: {
            Text(title).font(.custom("Montserrat-Medium", size: 12)).frame(maxWidth: .infinity)
                .foregroundStyle(createAccount == isCreate ? Color.white : AppPalette.ink)
        }.buttonStyle(.glassProminent).tint(createAccount == isCreate ? AppPalette.ink : AppPalette.frostBlue)
    }

    func fieldLabel(_ title: String) -> some View {
        return Text(title).font(.custom("Montserrat-SemiBold", size: 10)).tracking(1)
    }

    func submit() {
        notice = ""
        if createAccount {
            guard password == confirmation else { notice = "The passwords do not match."; return }
            guard password.count >= 6, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                notice = "Enter your name and a password with at least 6 characters."
                return
            }
        }
        Task {
            let success: Bool
            if createAccount { success = await account.signUp(email: email, password: password, displayName: name) }
            else { success = await account.signIn(email: email, password: password) }
            if success { password = ""; confirmation = ""; dismiss() }
        }
    }
}
