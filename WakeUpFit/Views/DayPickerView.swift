import SwiftUI

/// Apple-style day picker for alarm repeat schedule
struct DayPickerView: View {
    @Binding var selectedDays: Set<Int>
    
    // Calendar weekday integers: 1 = Sunday ... 7 = Saturday
    private let days: [(name: String, weekday: Int)] = [
        ("Every Sunday", 1),
        ("Every Monday", 2),
        ("Every Tuesday", 3),
        ("Every Wednesday", 4),
        ("Every Thursday", 5),
        ("Every Friday", 6),
        ("Every Saturday", 7),
    ]
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            List {
                ForEach(days, id: \.weekday) { day in
                    Button {
                        if selectedDays.contains(day.weekday) {
                            selectedDays.remove(day.weekday)
                        } else {
                            selectedDays.insert(day.weekday)
                        }
                    } label: {
                        HStack {
                            Text(day.name)
                                .foregroundStyle(Theme.textDark)
                            Spacer()
                            if selectedDays.contains(day.weekday) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.primary)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
