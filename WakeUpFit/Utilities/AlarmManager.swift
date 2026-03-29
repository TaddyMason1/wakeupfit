import Foundation
import UserNotifications
import AVFoundation

class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = [] {
        didSet {
            saveAlarms()
            scheduleNotifications()
        }
    }
    
    private let userDefaultsKey = "wakeUpFit_alarms"
    
    init() {
        loadAlarms()
        requestPermissions()
    }
    
    // MARK: - Persistence
    
    private func loadAlarms() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Alarm].self, from: data) else { return }
        self.alarms = sortChronologically(decoded)
    }
    
    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Permissions
    
    private func requestPermissions() {
        // TODO: Once Apple approves the Critical Alerts entitlement, add .criticalAlert here
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            } else {
                print("Notification permissions explicitly denied by user.")
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    private func scheduleNotifications() {
        // Clear old ones first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        for alarm in alarms where alarm.isEnabled {
            let content = UNMutableNotificationContent()
            content.title = "WAKE UP!"
            content.body = alarm.label
            content.categoryIdentifier = "ALARM"
            content.interruptionLevel = .timeSensitive
            
            // Use custom sound file for notification
            let soundName = AlarmSound(rawValue: alarm.soundId)?.filename ?? AlarmSound.alarm.filename
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
            
            // If the user selected repeat days, calculate trigger for each day
            if !alarm.repeatDays.isEmpty {
                for weekday in alarm.repeatDays {
                    var components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
                    components.weekday = weekday // 1 = Sunday, 2 = Monday, etc.
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(identifier: "\(alarm.id.uuidString)-\(weekday)", content: content, trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("Scheduling error: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                // One-off alarm
                let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Scheduling error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Intent API
    
    // MARK: - Sorting Helper
    
    private func sortChronologically(_ alarmsList: [Alarm]) -> [Alarm] {
        return alarmsList.sorted { a1, a2 in
            let c1 = Calendar.current.dateComponents([.hour, .minute], from: a1.time)
            let c2 = Calendar.current.dateComponents([.hour, .minute], from: a2.time)
            
            if c1.hour == c2.hour {
                return (c1.minute ?? 0) < (c2.minute ?? 0)
            }
            return (c1.hour ?? 0) < (c2.hour ?? 0)
        }
    }
    
    // MARK: - Intent API
    
    func add(alarm: Alarm) {
        var newAlarms = alarms
        newAlarms.append(alarm)
        alarms = sortChronologically(newAlarms)
    }
    
    func update(alarm: Alarm) {
        var newAlarms = alarms
        if let idx = newAlarms.firstIndex(where: { $0.id == alarm.id }) {
            newAlarms[idx] = alarm
            alarms = sortChronologically(newAlarms)
        }
    }
    
    func remove(id: UUID) {
        alarms.removeAll { $0.id == id }
    }
    
    func toggle(id: UUID) {
        if let idx = alarms.firstIndex(where: { $0.id == id }) {
            alarms[idx].isEnabled.toggle()
        }
    }
}
