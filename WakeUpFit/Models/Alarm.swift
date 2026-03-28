import Foundation

struct Alarm: Identifiable, Codable {
    var id: UUID
    var time: Date
    var label: String
    var repeatDays: Set<Int> // 1 (Sunday) to 7 (Saturday) - matching Calendar.current.component(.weekday)
    var soundId: String
    var isEnabled: Bool
    
    init(id: UUID = UUID(), time: Date = Date(), label: String = "Alarm", repeatDays: Set<Int> = [], soundId: String = "default", isEnabled: Bool = true) {
        self.id = id
        self.time = time
        self.label = label
        self.repeatDays = repeatDays
        self.soundId = soundId
        self.isEnabled = isEnabled
    }
}
