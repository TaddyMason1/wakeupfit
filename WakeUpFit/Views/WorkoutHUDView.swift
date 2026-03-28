import SwiftUI

/// HUD overlay showing exercise progress bar on the right side and rep counter
struct WorkoutHUDView: View {
    let exercise: ExerciseType
    let position: CGFloat       // 0.0 (bottom) to 1.0 (top)
    let completedReps: Int
    let targetReps: Int
    let isInGreenZone: Bool
    let showMoveBack: Bool
    let phase: ExerciseTracker.RepPhase
    let isInverted: Bool        // true for jumping jacks (green zone at top)

    // Green zone = 10% of bar height at the bottom
    private let barHeight: CGFloat = 280
    private let barWidth: CGFloat = 40
    private let greenZoneFraction: CGFloat = 0.25

    /// Clamped position to avoid negative frame dimensions
    private var clampedPosition: CGFloat {
        min(max(position, 0.0), 1.0)
    }

    var body: some View {
        ZStack {
            // MARK: - Right-side Progress Bar
            HStack {
                Spacer()

                // Use GeometryReader-free approach with explicit positioning
                ZStack {
                    // Track background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.surface)
                        .frame(width: barWidth, height: barHeight)

                    // Green zone
                    VStack(spacing: 0) {
                        if isInverted {
                            // Green zone at TOP for jumping jacks
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.primary.opacity(0.4))
                                .frame(width: barWidth - 8, height: barHeight * greenZoneFraction)
                            Spacer()
                        } else {
                            // Green zone at BOTTOM for squats/pushups
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.primary.opacity(0.4))
                                .frame(width: barWidth - 8, height: barHeight * greenZoneFraction)
                        }
                    }
                    .frame(width: barWidth, height: barHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Moving indicator — uses alignment guide to stay WITHIN the bar
                    // position 1.0 = top of bar, position 0.0 = bottom of bar
                    VStack(spacing: 0) {
                        // Top spacer pushes the bar down — more space = bar lower
                        Color.clear
                            .frame(height: max((1.0 - clampedPosition) * barHeight, 0))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(isInGreenZone ? Theme.primary : Color.white)
                            .frame(width: barWidth - 4, height: 6)
                            .shadow(color: isInGreenZone ? Theme.primary : .clear, radius: 8)

                        // Bottom spacer absorbs remaining space
                        Color.clear
                            .frame(height: max(clampedPosition * barHeight - 6, 0))
                    }
                    .frame(width: barWidth, height: barHeight)
                    .clipped()
                    .animation(.linear(duration: 0.1), value: clampedPosition)
                    .animation(.easeInOut(duration: 0.2), value: isInGreenZone)
                }
                .padding(.trailing, 20)
            }

            // MARK: - Top HUD (flush with Dynamic Island)
            VStack {
                HStack(alignment: .top) {
                    // Exercise label — top left
                    HStack(spacing: 8) {
                        Image(systemName: exercise.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(exercise.displayName)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textDark)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.surface)
                    .clipShape(Capsule())

                    Spacer()

                    // Rep counter — top right
                    Text("\(completedReps)/\(targetReps)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(completedReps >= targetReps ? Theme.primary : Theme.textDark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer()

                // Move back prompt
                if showMoveBack {
                    Text("Move back so your full body is visible")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textDark)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showMoveBack)
    }

    private var phaseLabel: String {
        switch phase {
        case .ready: return "READY"
        case .descending: return "↓ DOWN"
        case .bottom: return "✓ TARGET ZONE"
        case .ascending: return "↑ UP"
        }
    }
}
