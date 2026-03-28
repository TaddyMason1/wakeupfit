import AVFoundation
import UIKit

final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private init() {
        engine.attach(playerNode)
        // Standard format for speakers
        if let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1) {
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        }
        try? engine.start()
    }

    /// Plays a synthetic ping for a successful rep, guaranteed to have 0 vibration
    func playRepComplete() {
        let sampleRate = 44100.0
        let duration = 0.15
        let frequency = 880.0 // A5 note

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return
        }
        buffer.frameLength = buffer.frameCapacity

        let channels = buffer.floatChannelData!
        for i in 0..<Int(buffer.frameLength) {
            let time = Double(i) / sampleRate
            let envelope = exp(-time * 15.0) // quick fade
            channels[0][i] = Float(sin(2.0 * .pi * frequency * time) * envelope)
        }

        if !engine.isRunning { try? engine.start() }
        // scheduleBuffer automatically mixes/overwrites if interrupted
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        playerNode.play()
    }

    /// Plays a completion fanfare
    func playWorkoutComplete() {
        AudioServicesPlaySystemSound(1335) // celebration sound
    }

    /// (Unused fallback) Provides haptic feedback on rep completion
    func hapticFeedback() {
        // Disabled per user request
    }

    /// Plays a subtle tick/click for slot machine reel
    func playTick() {
        AudioServicesPlaySystemSound(1104) // subtle keyboard click
    }
}
