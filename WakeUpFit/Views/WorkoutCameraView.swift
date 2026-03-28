import SwiftUI

/// Main workout view: full-screen camera feed + HUD + workout selector
struct WorkoutCameraView: View {

    @StateObject private var cameraManager = CameraManager()
    @StateObject private var poseDetector = PoseDetector()
    @StateObject private var exerciseTracker: ExerciseTracker

    @State private var selectedExercise: ExerciseType = .squats
    @State private var showSelector = true
    @State private var showComplete = false
    @State private var showSkeleton = true // Debug skeleton overlay

    // Setup Phase
    @State private var prepCountdown = 0
    @State private var prepTimer: Timer? = nil

    init(exercise: ExerciseType = .squats, targetReps: Int? = nil) {
        _exerciseTracker = StateObject(wrappedValue: ExerciseTracker(
            exercise: exercise,
            targetReps: targetReps
        ))
        _selectedExercise = State(initialValue: exercise)
    }

    var body: some View {
        ZStack {
            // MARK: - Camera Feed
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            // MARK: - Skeleton Debug Overlay
            if showSkeleton && !showSelector {
                SkeletonOverlayView(
                    joints: poseDetector.jointPoints,
                    connections: poseDetector.bodyConnections,
                    position: poseDetector.exercisePosition,
                    phase: "\(exerciseTracker.phase)"
                )
                .ignoresSafeArea()
            }

            // MARK: - HUD
            if !showSelector {
                WorkoutHUDView(
                    exercise: exerciseTracker.exercise,
                    position: poseDetector.exercisePosition,
                    completedReps: exerciseTracker.completedReps,
                    targetReps: exerciseTracker.targetReps,
                    isInGreenZone: exerciseTracker.isInGreenZone,
                    showMoveBack: cameraManager.showMoveBackPrompt,
                    phase: exerciseTracker.phase,
                    isInverted: exerciseTracker.isInvertedExercise
                )
            }

            // MARK: - Workout Selector Overlay
            WorkoutSelectorOverlay(
                selectedExercise: $selectedExercise,
                isVisible: $showSelector
            )

            // MARK: - Switch Workout (top-left, below exercise label)
            if !showSelector && !showComplete {
                VStack {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSelector = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.trianglehead.2.counterclockwise")
                                Text("Switch")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 55)

                    Spacer()

                    // Skeleton toggle (bottom-right)
                    HStack {
                        Spacer()
                        Button {
                            showSkeleton.toggle()
                        } label: {
                            Image(systemName: showSkeleton ? "figure.stand" : "figure.stand.line.dotted.figure.stand")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(showSkeleton ? .green : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 40)
                }
            }

            // MARK: - Prep Countdown Overlay
            if prepCountdown > 0 {
                VStack(spacing: 16) {
                    Text("Get into position")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("\(prepCountdown)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 12)
                // Slight pulse effect on number change
                .id(prepCountdown)
                .transition(.asymmetric(insertion: .scale(scale: 1.5).combined(with: .opacity), removal: .opacity))
            }
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: showSelector) { showing in
            if !showing {
                startPrepCountdown()
            } else {
                prepTimer?.invalidate()
                prepCountdown = 0
            }
        }
        .onChange(of: selectedExercise) { newExercise in
            exerciseTracker.switchExercise(to: newExercise)
            poseDetector.resetCalibration()
        }
        .onChange(of: exerciseTracker.isComplete) { complete in
            if complete {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showComplete = true
                }
            }
        }
        .fullScreenCover(isPresented: $showComplete) {
            WorkoutCompleteView(
                exercise: exerciseTracker.exercise,
                reps: exerciseTracker.completedReps
            )
        }
        .statusBarHidden()
    }

    // MARK: - Setup

    private func setupCamera() {
        cameraManager.onFrame = { buffer in
            guard !self.showSelector else { return }

            self.poseDetector.processFrame(buffer, for: self.exerciseTracker.exercise)

            // Update camera zoom based on body visibility
            self.cameraManager.updateBodyVisibility(
                allJointsVisible: self.poseDetector.allJointsVisible
            )

            // Update exercise tracker with pose position
            DispatchQueue.main.async {
                if self.prepCountdown > 0 {
                    // Continuously reset calibration while they get into position
                    // so it perfectly snapshots their final neutral pose when timer ends
                    self.poseDetector.resetCalibration()
                } else {
                    self.exerciseTracker.update(position: self.poseDetector.exercisePosition)
                }
            }
        }

        cameraManager.configure()
        cameraManager.startSession()
    }

    // MARK: - Prep Countdown

    private func startPrepCountdown() {
        prepCountdown = 5
        prepTimer?.invalidate()

        prepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard self.prepCountdown > 0 else {
                timer.invalidate()
                return
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.prepCountdown -= 1
            }

            if self.prepCountdown > 0 {
                SoundManager.shared.playTick()
            } else {
                SoundManager.shared.playRepComplete()
                timer.invalidate()
            }
        }
    }
}
