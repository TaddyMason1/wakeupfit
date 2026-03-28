import SwiftUI

/// Apple-style Add/Edit Alarm sheet with time picker until form fields
struct AddEditAlarmView: View {
    @ObservedObject var alarmManager: AlarmManager
    @Environment(\.dismiss) private var dismiss
    
    let alarm: Alarm?  // nil = adding new, non-nil = editing existing
    
    @State private var time: Date
    @State private var label: String
    @State private var repeatDays: Set<Int>
    @State private var soundId: String
    
    init(alarmManager: AlarmManager, alarm: Alarm?) {
        self.alarmManager = alarmManager
        self.alarm = alarm
        _time = State(initialValue: alarm?.time ?? Date())
        _label = State(initialValue: alarm?.label ?? "Alarm")
        _repeatDays = State(initialValue: alarm?.repeatDays ?? [])
        _soundId = State(initialValue: alarm?.soundId ?? AlarmSound.allCases.first?.rawValue ?? "default")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Time Picker (top half, like Apple)
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.light)
                        .padding(.top, 8)
                        .tint(Theme.primary)
                    
                    // MARK: - Form Fields
                    List {
                        // Repeat
                        NavigationLink {
                            DayPickerView(selectedDays: $repeatDays)
                        } label: {
                            HStack {
                                Text("Repeat")
                                    .foregroundStyle(Theme.textDark)
                                Spacer()
                                Text(repeatSummary)
                                    .foregroundStyle(Theme.textDark.opacity(0.5))
                            }
                        }
                        .listRowBackground(Theme.surface)
                        
                        // Label
                        HStack {
                            Text("Label")
                                .foregroundStyle(Theme.textDark)
                            Spacer()
                            TextField("Alarm", text: $label)
                                .foregroundStyle(Theme.textDark)
                                .multilineTextAlignment(.trailing)
                        }
                        .listRowBackground(Theme.surface)
                        
                        // Sound
                        NavigationLink {
                            AlarmSoundPickerView(selectedSoundId: $soundId)
                        } label: {
                            HStack {
                                Text("Sound")
                                    .foregroundStyle(Theme.textDark)
                                Spacer()
                                Text(selectedSoundName)
                                    .foregroundStyle(Theme.textDark.opacity(0.5))
                            }
                        }
                        .listRowBackground(Theme.surface)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    
                    // Delete button (only when editing)
                    if alarm != nil {
                        Button(role: .destructive) {
                            if let alarm = alarm {
                                alarmManager.remove(id: alarm.id)
                            }
                            dismiss()
                        } label: {
                            Text("Delete Alarm")
                                .font(.system(size: 17))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(alarm == nil ? "Add Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func save() {
        if var existing = alarm {
            existing.time = time
            existing.label = label
            existing.repeatDays = repeatDays
            existing.soundId = soundId
            alarmManager.update(alarm: existing)
        } else {
            let newAlarm = Alarm(
                time: time,
                label: label,
                repeatDays: repeatDays,
                soundId: soundId,
                isEnabled: true
            )
            alarmManager.add(alarm: newAlarm)
        }
    }
    
    private var repeatSummary: String {
        if repeatDays.isEmpty { return "Never" }
        if repeatDays.count == 7 { return "Every day" }
        
        let dayAbbreviations = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sorted = repeatDays.sorted()
        
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        
        return sorted.map { dayAbbreviations[$0] }.joined(separator: " ")
    }
    
    private var selectedSoundName: String {
        AlarmSound.allCases.first(where: { $0.rawValue == soundId })?.displayName ?? "Default"
    }
}
