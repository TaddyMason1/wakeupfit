import Foundation
import AudioToolbox
import AVFoundation

/// Selectable alarm sounds.
/// Each case's rawValue is the exact filename (without extension) in the bundle.
enum AlarmSound: String, CaseIterable, Identifiable {
    case alarm = "Alarm"
    case basedThomas = "Based Thomas"
    case nuclearSiren = "Nuclear Siren"
    case xueHuaPiaoPiao = "Xue Hua Piao Piao"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        return self.rawValue
    }
    
    /// The filename with extension for notification sound and playback
    var filename: String {
        return "\(self.rawValue).caf"
    }
    
    /// Play a short preview of this sound
    private static var previewPlayer: AVAudioPlayer?
    
    func playPreview() {
        // Stop any existing preview first
        AlarmSound.stopPreview()
        
        guard let url = Bundle.main.url(forResource: self.rawValue, withExtension: "caf") else {
            print("AlarmSound: Could not find \(filename) in bundle")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            AlarmSound.previewPlayer = try AVAudioPlayer(contentsOf: url)
            AlarmSound.previewPlayer?.play()
        } catch {
            print("AlarmSound: Preview error: \(error.localizedDescription)")
        }
    }
    
    /// Stop any currently playing preview
    static func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }
}
