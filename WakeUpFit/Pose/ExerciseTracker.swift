import Foundation
import Combine

/// State machine that tracks exercise reps based on position values from PoseDetector
final class ExerciseTracker: ObservableObject {

    // MARK: - Published

    @Published var exercise: ExerciseType
    @Published var targetReps: Int
    @Published private(set) var completedReps: Int = 0
    @Published private(set) var isComplete: Bool = false
    @Published private(set) var isInGreenZone: Bool = false

    // MARK: - State Machine

    enum RepPhase {
        case ready       // Standing/up position
        case descending  // Moving toward bottom
        case bottom      // In the green zone
        case ascending   // Coming back up
    }

    @Published private(set) var phase: RepPhase = .ready

    // MARK: - Thresholds

    /// Position below this = entering the green zone (bottom of movement)
    private let greenZoneThreshold: CGFloat = 0.25

    /// Position above this = back to ready (top of movement)
    /// Must be well above greenZone to prevent state machine jitter
    private let readyThreshold: CGFloat = 0.65

    /// For jumping jacks, the logic is inverted (1.0 = arms up = "bottom" of rep)
    var isInvertedExercise: Bool {
        exercise == .jumpingJacks
    }

    // MARK: - Init

    init(exercise: ExerciseType, targetReps: Int? = nil) {
        self.exercise = exercise
        self.targetReps = targetReps ?? exercise.defaultReps
    }

    // MARK: - Update

    /// Called each frame with the normalized position (0.0-1.0) from PoseDetector
    func update(position: CGFloat) {
        guard !isComplete else { return }

        let effectivePosition = isInvertedExercise ? (1.0 - position) : position

        let inGreen = effectivePosition <= greenZoneThreshold
        isInGreenZone = inGreen

        switch phase {
        case .ready:
            if effectivePosition < readyThreshold {
                phase = .descending
            }

        case .descending:
            if inGreen {
                phase = .bottom
                // Play ding when entering green zone
                SoundManager.shared.playRepComplete()
            } else if effectivePosition >= readyThreshold {
                // They went back up without reaching bottom
                phase = .ready
            }

        case .bottom:
            if effectivePosition > greenZoneThreshold {
                phase = .ascending
            }

        case .ascending:
            if effectivePosition >= readyThreshold {
                // Full rep completed!
                completedReps += 1
                phase = .ready

                if completedReps >= targetReps {
                    isComplete = true
                    SoundManager.shared.playWorkoutComplete()
                }
            } else if inGreen {
                // Went back down
                phase = .bottom
            }
        }
    }

    // MARK: - Reset

    func reset() {
        completedReps = 0
        isComplete = false
        phase = .ready
        isInGreenZone = false
    }

    func switchExercise(to newExercise: ExerciseType) {
        exercise = newExercise
        reset()
    }
}
