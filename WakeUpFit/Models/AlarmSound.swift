import Foundation
import AudioToolbox

/// Selectable alarm sounds.
/// "default" uses the iOS system notification sound.
/// When you add custom audio files, add a new case with the exact bundled filename as the rawValue.
enum AlarmSound: String, CaseIterable, Identifiable {
    case `default` = "default"
    // TODO: Add custom sounds like:  case sunrise = "Sunrise.m4a"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .default: return "Default (Alarm)"
        }
    }
    
    /// System Sound ID used for live preview in the picker
    var previewSoundId: SystemSoundID {
        switch self {
        case .default: return 1005  // Alarm
        }
    }
    
    /// Play a short preview of this sound
    func playPreview() {
        AudioServicesPlaySystemSound(previewSoundId)
    }
}

