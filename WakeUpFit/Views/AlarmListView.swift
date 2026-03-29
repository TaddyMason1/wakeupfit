import SwiftUI
import UserNotifications
import RevenueCatUI

/// Apple-style alarm list — the main screen of the app
struct AlarmListView: View {
    @StateObject private var alarmManager = AlarmManager()
    @State private var showAddAlarm = false
    @State private var editingAlarm: Alarm? = nil
    @State private var showWorkout = false
    @State private var isEditing = false
    @State private var showPaywall = false
    
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.background)
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.textDark)]
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.textDark)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                // Custom heading that stays visible
                HStack {
                    Text("Alarms")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textDark)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
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
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(alarmManager.alarms) { alarm in
                            HStack(spacing: 12) {
                                if isEditing {
                                    Button {
                                        withAnimation {
                                            alarmManager.remove(id: alarm.id)
                                            if alarmManager.alarms.isEmpty {
                                                isEditing = false
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(.red)
                                    }
                                }
                                
                                AlarmRow(alarm: alarm, onToggle: {
                                    alarmManager.toggle(id: alarm.id)
                                })
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isEditing {
                                    editingAlarm = alarm
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !alarmManager.alarms.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation {
                                isEditing.toggle()
                            }
                        }
                        .foregroundStyle(Theme.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        showPaywall = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
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
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive
        
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
