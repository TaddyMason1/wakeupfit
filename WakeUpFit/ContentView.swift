import SwiftUI

struct ContentView: View {
    @State private var showWorkout = false

    var body: some View {
        ZStack {
            // Background
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo area
                VStack(spacing: 16) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.primary)

                    Text("Wake Up Fit")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textDark)

                    Text("Complete a workout to silence your alarm")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textDark.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Start Workout button (for Stage 1 testing)
                Button {
                    showWorkout = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showWorkout) {
            WorkoutCameraView()
        }
    }
}

#Preview {
    ContentView()
}
