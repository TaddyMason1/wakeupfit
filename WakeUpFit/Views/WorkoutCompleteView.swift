import SwiftUI

/// Celebration screen after completing the workout
struct WorkoutCompleteView: View {
    let exercise: ExerciseType
    let reps: Int

    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Background
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Checkmark
                ZStack {
                    Circle()
                        .fill(Theme.primary.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(Theme.primary, lineWidth: 3)
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Theme.primary)
                }
                .scaleEffect(showContent ? 1.0 : 0.3)
                .opacity(showContent ? 1.0 : 0.0)

                // Text
                VStack(spacing: 12) {
                    Text("Workout Complete!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textDark)

                    Text("\(reps) \(exercise.displayName)")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDark.opacity(0.8))

                    Text("You're awake now 💪")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textDark.opacity(0.8))
                        .padding(.top, 4)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)

                Spacer()

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(showContent ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showContent = true
            }
        }
    }
}
