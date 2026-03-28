import SwiftUI
import UserNotifications

/// Apple-style alarm list — the main screen of the app
struct AlarmListView: View {
    @StateObject private var alarmManager = AlarmManager()
    @State private var showAddAlarm = false
    @State private var editingAlarm: Alarm? = nil
    @State private var showWorkout = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                if alarmManager.alarms.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "alarm")
                            .font(.system(size: 64))
                            .foregroundStyle(Theme.primary.opacity(0.5))
                        
                        Text("No Alarms")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textDark.opacity(0.6))
                        
                        Text("Tap + to set your first alarm")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textDark.opacity(0.4))
                    }
                } else {
                    List {
                        ForEach(alarmManager.alarms) { alarm in
                            AlarmRow(alarm: alarm, onToggle: {
                                alarmManager.toggle(id: alarm.id)
                            })
                            .listRowBackground(Theme.surface)
                            .listRowSeparatorTint(Theme.accent.opacity(0.2))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingAlarm = alarm
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                alarmManager.remove(id: alarmManager.alarms[index].id)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Alarms")
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                // Force nav bar title to Obsidian Blue so it's legible on the light background
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Theme.background)
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.textDark)]
                appearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.textDark)]
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !alarmManager.alarms.isEmpty {
                        EditButton()
                            .foregroundStyle(Theme.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddAlarm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showAddAlarm) {
                AddEditAlarmView(alarmManager: alarmManager, alarm: nil)
            }
            .sheet(item: $editingAlarm) { alarm in
                AddEditAlarmView(alarmManager: alarmManager, alarm: alarm)
            }
            .fullScreenCover(isPresented: $showWorkout, onDismiss: {
                // Workout completed — silence the alarm
                AlarmPlayer.shared.stop()
            }) {
                WorkoutCameraView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .alarmFired)) { _ in
                AlarmPlayer.shared.start()
                showWorkout = true
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    scheduleTestAlarm()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                        Text("Test Alarm (3s)")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Test Alarm
    
    private func scheduleTestAlarm() {
        let content = UNMutableNotificationContent()
        content.title = "WAKE UP!"
        content.body = "Test Alarm"
        content.sound = .default
        
        // Fire in 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "test-alarm", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Test alarm error: \(error.localizedDescription)")
            } else {
                print("Test alarm scheduled — fires in 3 seconds")
            }
        }
    }
}

// MARK: - Alarm Row

struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Time — large like Apple's alarm list
                Text(timeString)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(alarm.isEnabled ? Theme.textDark : Theme.textDark.opacity(0.35))
                
                // Label + repeat info
                HStack(spacing: 6) {
                    Text(alarm.label)
                        .font(.system(size: 14))
                    
                    if !alarm.repeatDays.isEmpty {
                        Text(repeatSummary)
                            .font(.system(size: 14))
                    }
                }
                .foregroundStyle(alarm.isEnabled ? Theme.textDark.opacity(0.6) : Theme.textDark.opacity(0.25))
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in onToggle() }
            ))
            .tint(Theme.primary)
            .labelsHidden()
        }
        .padding(.vertical, 6)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: alarm.time)
    }
    
    private var repeatSummary: String {
        if alarm.repeatDays.count == 7 {
            return "Every day"
        }
        
        let dayAbbreviations = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sorted = alarm.repeatDays.sorted()
        
        // Check for weekdays
        if sorted == [2, 3, 4, 5, 6] {
            return "Weekdays"
        }
        // Check for weekends
        if sorted == [1, 7] {
            return "Weekends"
        }
        
        return sorted.map { dayAbbreviations[$0] }.joined(separator: " ")
    }
}

#Preview {
    AlarmListView()
}
