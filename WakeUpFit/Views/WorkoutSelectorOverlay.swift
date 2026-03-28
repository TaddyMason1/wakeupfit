import SwiftUI

/// Slot-machine style workout selector — horizontal infinite reel in the center
struct WorkoutSelectorOverlay: View {
    @Binding var selectedExercise: ExerciseType
    @Binding var isVisible: Bool
    @State private var isSpinning = false
    @State private var reelOffset: CGFloat = 0
    @State private var settled = false

    private let exercises = ExerciseType.allCases
    private let cellWidth: CGFloat = 160
    private let cellHeight: CGFloat = 180
    private let cellSpacing: CGFloat = 16
    private let visibleWidth: CGFloat = 360

    // Many repetitions for infinite-scroll illusion
    private let repetitions = 21

    var body: some View {
        if isVisible {
            ZStack {
                // Entire-screen invisible layer to catch taps and center contents
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    // MARK: - Horizontal Slot Reel
                    ZStack {
                        // Reel strip — scrolls horizontally
                        HStack(spacing: 16) {
                            ForEach(0..<reelItems.count, id: \.self) { i in
                                exerciseCell(reelItems[i])
                            }
                        }
                        .offset(x: reelOffset)

                        // Selection highlight (primary color glow when settled)
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                Theme.primary.opacity(settled ? 0.9 : 0.0),
                                lineWidth: 3
                            )
                            .frame(width: cellWidth - 10, height: cellHeight - 10)
                            .shadow(color: Theme.primary.opacity(settled ? 0.5 : 0), radius: 16)
                            .animation(.easeOut(duration: 0.3), value: settled)
                    }
                    .frame(width: visibleWidth, height: cellHeight)
                    // Mask with linear gradient for left/right depth fade
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.25),
                                .init(color: .black, location: 0.75),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                    // MARK: - Buttons
                    HStack(spacing: 24) {
                        // Respin Button
                        Button(action: spin) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.trianglehead.2.counterclockwise")
                                    .font(.system(size: 17, weight: .bold))
                                Text("Respin")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundStyle(Theme.textDark)
                            .frame(width: 140, height: 54)
                            .background(Theme.surface)
                            .clipShape(Capsule())
                        }
                        .disabled(isSpinning)
                        .opacity(isSpinning ? 0.5 : 1.0)

                        // Start Button
                        Button(action: confirm) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Start")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundStyle(Theme.textDark)
                            .frame(width: 140, height: 54)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                        }
                        .disabled(isSpinning)
                        .opacity(isSpinning ? 0.5 : 1.0)
                    }
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .onAppear {
                setReelToExercise(selectedExercise, animated: false)
                settled = true
            }
        }
    }

    // MARK: - Infinite Reel Items

    private var reelItems: [ExerciseType] {
        // Repeat exercises many times for infinite scroll illusion
        Array(repeating: exercises, count: repetitions).flatMap { $0 }
    }

    // MARK: - Exercise Cell

    private func exerciseCell(_ exercise: ExerciseType) -> some View {
        VStack(spacing: 12) {
            Image(systemName: exercise.icon)
                .font(.system(size: 56))
                .foregroundStyle(Theme.primary)
            Text(exercise.shortName)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textDark.opacity(0.95))
        }
        .frame(width: cellWidth, height: cellHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.background)
        )
    }

    // MARK: - Reel Positioning

    /// Calculates exact offset to center the given index, knowing HStack aligns its center naturally
    private func offset(for targetIndex: Int) -> CGFloat {
        let stride = cellWidth + cellSpacing
        let centerIndex = CGFloat(reelItems.count - 1) / 2.0
        let distanceFromCenter = CGFloat(targetIndex) - centerIndex
        return -distanceFromCenter * stride
    }

    private func setReelToExercise(_ exercise: ExerciseType, animated: Bool) {
        guard let idx = exercises.firstIndex(of: exercise) else { return }

        // Target the middle repetition so we have room to spin in both directions
        let middleRepStart = exercises.count * (repetitions / 2)
        let targetIndex = middleRepStart + idx

        let targetOffset = offset(for: targetIndex)

        if animated {
            withAnimation(.interpolatingSpring(stiffness: 50, damping: 9)) {
                reelOffset = targetOffset
            }
        } else {
            reelOffset = targetOffset
        }
    }

    // MARK: - Spin

    private func spin() {
        isSpinning = true
        settled = false

        // Pick a random different exercise
        var newExercise = exercises.randomElement()!
        if exercises.count > 1 {
            while newExercise == selectedExercise {
                newExercise = exercises.randomElement()!
            }
        }

        let currentBaseIndex = exercises.firstIndex(of: selectedExercise) ?? 0
        let newBaseIndex = exercises.firstIndex(of: newExercise) ?? 0
        
        // Exact index currently centered (guaranteed in middle repetition via onAppear)
        let currentIdx = exercises.count * (repetitions / 2) + currentBaseIndex

        // Phase 1: Quick kick backwards
        SoundManager.shared.playTick()
        withAnimation(.easeIn(duration: 0.15)) {
            reelOffset = offset(for: currentIdx) + cellWidth * 0.4
        }

        // Phase 2: Rapid ticks as reel spins
        for i in 1...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                SoundManager.shared.playTick()
            }
        }

        // Phase 3: Spin several cells then settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            // Target is 2 full cycles (6 items) ahead plus the difference
            let targetIdx = currentIdx + exercises.count * 2 + (newBaseIndex - currentBaseIndex)

            withAnimation(.easeOut(duration: 0.8)) {
                reelOffset = offset(for: targetIdx)
            }

            selectedExercise = newExercise

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                SoundManager.shared.playTick()
                settled = true
                isSpinning = false
            }
        }
    }

    // MARK: - Confirm

    private func confirm() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = false
        }
    }
}

// MARK: - Short Names

extension ExerciseType {
    var shortName: String {
        switch self {
        case .squats: return "Squats"
        case .pushups: return "Push-ups"
        case .jumpingJacks: return "Jacks"
        }
    }
}
