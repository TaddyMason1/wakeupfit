import Foundation
import AVFoundation

/// Manages a looping alarm sound that plays until explicitly stopped (i.e., workout completed).
class AlarmPlayer: ObservableObject {
    static let shared = AlarmPlayer()
    
    @Published var isPlaying = false
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    /// Start the alarm sound on an infinite loop
    func start(sound: AlarmSound = .alarm) {
        guard !isPlaying else { return }
        
        // Configure audio session for loud playback even on silent switch
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AlarmPlayer: Audio session error: \(error.localizedDescription)")
        }
        
        // Load and loop the custom sound file
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") else {
            print("AlarmPlayer: Could not find \(sound.filename) in bundle")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop forever
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("AlarmPlayer: Playback error: \(error.localizedDescription)")
        }
    }
    
    /// Stop the alarm — called when the workout is completed
    func stop() {
        isPlaying = false
        audioPlayer?.stop()
        audioPlayer = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AlarmPlayer: Deactivation error: \(error.localizedDescription)")
        }
    }
}
