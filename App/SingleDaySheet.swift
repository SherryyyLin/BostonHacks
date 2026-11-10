import SwiftUI

struct SingleDaySheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text("Just one day.").font(.custom("Montserrat-Bold", size: 28))
                Text("See hackathons happening on the day you choose.")
                    .font(.custom("Montserrat-Regular", size: 13))
                DatePicker("Choose a day", selection: $day, displayedComponents: [.date])
                    .datePickerStyle(.graphical).tint(AppPalette.purpleInk)
                Text("This covers midnight to midnight in Boston time, including events already in progress.")
                    .font(.custom("Montserrat-Regular", size: 11)).foregroundStyle(AppPalette.secondary)
                Button {
                    let start = bostonCalendar().startOfDay(for: day)
                    guard let end = bostonCalendar().date(byAdding: .day, value: 1, to: start) else { return }
                    startDate = start
                    endDate = end
                    onApply()
                    dismiss()
                } label: {
                    Label("Use this day", systemImage: "checkmark").foregroundStyle(.white)
                        .font(.custom("Montserrat-SemiBold", size: 14)).frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.glassProminent).tint(AppPalette.ink)
                Spacer()
            }.padding(24).background(AppPalette.backgroundGradient).foregroundStyle(AppPalette.ink)
                .navigationTitle("Choose one day").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Cancel") { dismiss() }.buttonStyle(.glassProminent).tint(AppPalette.frostBlue) }
                .onAppear { day = startDate }
        }.environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.timeZone, bostonCalendar().timeZone)
    }
}
