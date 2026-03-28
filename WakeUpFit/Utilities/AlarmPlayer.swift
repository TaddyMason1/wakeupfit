import Foundation
import AVFoundation
import AudioToolbox

/// Manages a looping alarm sound that plays until explicitly stopped (i.e., workout completed).
class AlarmPlayer: ObservableObject {
    static let shared = AlarmPlayer()
    
    @Published var isPlaying = false
    private var audioPlayer: AVAudioPlayer?
    private var repeatTimer: Timer?
    
    private init() {}
    
    /// Start the alarm sound on an infinite loop
    func start() {
        guard !isPlaying else { return }
        
        // Configure audio session for loud playback even on silent switch
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AlarmPlayer: Audio session error: \(error.localizedDescription)")
        }
        
        // Use the system Tri-Tone as a repeating alarm via AudioServices
        // Since system sounds are short, we loop them with a timer
        isPlaying = true
        playSystemSound()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.playSystemSound()
        }
    }
    
    /// Stop the alarm — called when the workout is completed
    func stop() {
        isPlaying = false
        repeatTimer?.invalidate()
        repeatTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AlarmPlayer: Deactivation error: \(error.localizedDescription)")
        }
    }
    
    private func playSystemSound() {
        AudioServicesPlaySystemSound(1005) // Alarm
    }
}
