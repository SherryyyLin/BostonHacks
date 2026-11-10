import SwiftUI

struct DateRangeSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    var initialStep: Int = 0
    var onApply: (() -> Void)? = nil

    // Classroom @State and DatePicker: edits stay in a draft until Apply.
    @State private var draftStart = Date()
    @State private var draftEnd = Date().addingTimeInterval(3_600)
    @State private var step = 0
    @State private var message = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                        Text("PLAN YOUR NEXT BUILD")
                            .font(.custom("Montserrat-SemiBold", size: 11))
                    }.foregroundStyle(AppPalette.accent)

                    Text(step == 0 ? "When do you want to start?" : "When does your window end?")
                        .font(.custom("Montserrat-Bold", size: 27))

                    // Like a booking form, both ends remain visible while editing.
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("START").font(.custom("Montserrat-Bold", size: 10))
                                .foregroundStyle(AppPalette.purpleInk)
                            Text(dateText(draftStart, pattern: "EEE, MMM d"))
                                .font(.custom("Montserrat-SemiBold", size: 14))
                                .foregroundStyle(AppPalette.purpleInk)
                            Text(dateText(draftStart, pattern: "h:mm a"))
                                .font(.custom("Montserrat-Regular", size: 13)).foregroundStyle(AppPalette.purpleInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(AppPalette.lavender.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(step == 0 ? AppPalette.purpleInk : Color.clear))

                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("END").font(.custom("Montserrat-Bold", size: 10))
                                .foregroundStyle(AppPalette.pinkInk)
                            Text(dateText(draftEnd, pattern: "EEE, MMM d"))
                                .font(.custom("Montserrat-SemiBold", size: 14))
                                .foregroundStyle(AppPalette.pinkInk)
                            Text(dateText(draftEnd, pattern: "h:mm a"))
                                .font(.custom("Montserrat-Regular", size: 13)).foregroundStyle(AppPalette.pinkInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(AppPalette.dustyPink.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(step == 1 ? AppPalette.pinkInk : Color.clear))
                    }

                    HStack {
                        Text(step == 0 ? "1 OF 2 · START DATE & TIME" : "2 OF 2 · END DATE & TIME")
                            .font(.custom("Montserrat-SemiBold", size: 11))
                        Spacer()
                        Text("BOSTON TIME · ET").font(.custom("Montserrat-Regular", size: 10)).foregroundStyle(AppPalette.secondary)
                    }

                    if step == 0 {
                        DatePicker("Start date & time", selection: $draftStart,
                                   displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical).tint(AppPalette.purpleInk)
                            .accessibilityIdentifier("range-start-picker")
                    } else {
                        DatePicker("End date & time", selection: $draftEnd, in: draftStart...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical).tint(AppPalette.pinkInk)
                            .accessibilityIdentifier("range-end-picker")
                    }

                    Text("Choose a day on the calendar, then tap the time to set hours and minutes. Events that overlap your window will appear in both the list and map.")
                        .font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(AppPalette.secondary)

                    if !message.isEmpty {
                        Text(message).font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(.red)
                    }
                    if step == 1 && draftEnd <= draftStart {
                        Text("Choose an end time after the start time.")
                            .font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(.red)
                    }
                }.padding(22)
            }
            .background(AppPalette.backgroundGradient)
            .navigationTitle(step == 0 ? "Start date & time" : "End date & time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Cancel").foregroundStyle(AppPalette.ink)
                    }
                        .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                        .accessibilityIdentifier("cancel-date-range")
                }
                if step == 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { step = 0; message = "" } label: {
                            Text("Back").foregroundStyle(AppPalette.ink)
                        }
                            .buttonStyle(.glassProminent).tint(AppPalette.frostBlue)
                            .accessibilityIdentifier("date-range-back")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if step == 0 {
                        Button {
                            step = 1
                            message = ""
                        } label: {
                            Label("Next: End time", systemImage: "arrow.right")
                                .font(.custom("Montserrat-SemiBold", size: 14)).foregroundStyle(.white)
                        }
                        .buttonStyle(.glassProminent).tint(AppPalette.ink)
                        .accessibilityIdentifier("date-range-next")
                    } else {
                        Button { applyRange() } label: {
                            Label("Apply range", systemImage: "checkmark")
                                .font(.custom("Montserrat-SemiBold", size: 14)).foregroundStyle(.white)
                        }
                            .buttonStyle(.glassProminent).tint(AppPalette.ink)
                            .disabled(draftEnd <= draftStart)
                            .accessibilityIdentifier("apply-date-range")
                    }
                    Text("Changes are saved only when you apply the range.")
                        .font(.custom("Montserrat-Regular", size: 10)).foregroundStyle(AppPalette.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 22)
                .background(.regularMaterial)
            }
            .onAppear {
                draftStart = startDate
                draftEnd = endDate
                step = initialStep == 1 ? 1 : 0
                keepEndAfterStart(draftStart)
            }
            .onChange(of: draftStart) { _, value in keepEndAfterStart(value) }
        }
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.timeZone, bostonCalendar().timeZone)
    }

    func keepEndAfterStart(_ start: Date) {
        if draftEnd <= start {
            guard let newEnd = bostonCalendar().date(byAdding: .hour, value: 1, to: start) else {
                message = "Could not adjust the end time. Please choose another start time."
                print("😡 ERROR: Could not add one hour to date-range start \(start).")
                return
            }
            draftEnd = newEnd
        }
    }

    func applyRange() {
        guard draftEnd > draftStart else {
            message = "The end time must be after the start time."
            print("😡 ERROR: Invalid date range: \(draftStart) to \(draftEnd).")
            return
        }
        startDate = draftStart
        endDate = draftEnd
        onApply?()
        dismiss()
    }
}
