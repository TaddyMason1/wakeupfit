import Vision
import CoreMedia
import Combine
import simd

/// Detects human body pose from camera frames and publishes joint positions
final class PoseDetector: ObservableObject {

    // MARK: - Published

    /// Normalized position value for the current exercise (0.0 = bottom, 1.0 = top)
    @Published var exercisePosition: CGFloat = 1.0

    /// Whether all required joints for the current exercise are visible
    @Published var allJointsVisible: Bool = false

    /// Raw joint points in Vision coordinates (for debug skeleton overlay)
    @Published var jointPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    /// Detected body connections for skeleton drawing
    @Published var bodyConnections: [(CGPoint, CGPoint)] = []

    // MARK: - Calibration State

    /// Tracks the maximum hip height seen (standing position) for squats
    private var maxHipY: CGFloat = 0.0
    /// Tracks the minimum wrist height seen (arms down) for jumping jacks
    private var minWristY: CGFloat = 1.0
    /// Tracks the maximum wrist height seen (arms up) for jumping jacks
    private var maxWristY: CGFloat = 0.0
    /// Tracks the maximum nose height for push-ups
    private var maxNoseY: CGFloat = 0.0
    /// Frame counter for calibration stability
    private var frameCount: Int = 0

    // MARK: - Private

    private let request = VNDetectHumanBodyPoseRequest()

    // MARK: - Skeleton connections for debug drawing

    private let connectionPairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.nose, .leftShoulder), (.nose, .rightShoulder),
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    // MARK: - Reset calibration when switching exercises

    func resetCalibration() {
        maxHipY = 0.0
        minWristY = 1.0
        maxWristY = 0.0
        maxNoseY = 0.0
        frameCount = 0
    }

    // MARK: - Process Frame

    func processFrame(_ sampleBuffer: CMSampleBuffer, for exercise: ExerciseType) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Buffer arrives in portrait format (videoOrientation = .portrait),
        // so use .up — no rotation needed.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let results = request.results, !results.isEmpty else {
            DispatchQueue.main.async {
                self.allJointsVisible = false
                self.jointPoints = [:]
                self.bodyConnections = []
            }
            return
        }

        // Pick the person closest to the camera (largest body area on screen)
        let observation = pickClosestPerson(from: results)

        // Extract all recognized points
        let points = extractJoints(from: observation)

        // Build skeleton connections
        let connections = buildConnections(points: points)

        // Check visibility of required joints
        let visible = checkVisibility(points: points, for: exercise)

        // Only calculate position when the body is fully visible
        // Prevents false readings from partial detection
        let rawPosition: CGFloat
        if visible {
            rawPosition = calculatePosition(points: points, for: exercise)
            frameCount += 1
        } else {
            rawPosition = 1.0 // Default to standing position
        }

        DispatchQueue.main.async {
            self.jointPoints = points
            self.bodyConnections = connections
            self.allJointsVisible = visible
            self.exercisePosition = rawPosition
        }
    }

    // MARK: - Multi-person: Pick the closest person (largest on screen)

    private func pickClosestPerson(
        from observations: [VNHumanBodyPoseObservation]
    ) -> VNHumanBodyPoseObservation {
        guard observations.count > 1 else { return observations[0] }

        // Score each person by the bounding area of their detected joints
        // The closest person will have the largest spread across the frame
        var bestObservation = observations[0]
        var bestArea: CGFloat = 0

        for obs in observations {
            var minX: CGFloat = 1.0, maxX: CGFloat = 0.0
            var minY: CGFloat = 1.0, maxY: CGFloat = 0.0
            var jointCount = 0

            let jointNames: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .leftShoulder, .rightShoulder,
                .leftHip, .rightHip, .leftWrist, .rightWrist,
                .leftAnkle, .rightAnkle
            ]

            for name in jointNames {
                if let point = try? obs.recognizedPoint(name),
                   point.confidence > 0.2 {
                    minX = min(minX, point.location.x)
                    maxX = max(maxX, point.location.x)
                    minY = min(minY, point.location.y)
                    maxY = max(maxY, point.location.y)
                    jointCount += 1
                }
            }

            // Area * joint count — prioritizes both size and detection quality
            let area = (maxX - minX) * (maxY - minY) * CGFloat(jointCount)
            if area > bestArea {
                bestArea = area
                bestObservation = obs
            }
        }

        return bestObservation
    }

    // MARK: - Connection Building

    private func buildConnections(
        points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> [(CGPoint, CGPoint)] {
        var connections: [(CGPoint, CGPoint)] = []
        for (a, b) in connectionPairs {
            if let pa = points[a], let pb = points[b] {
                connections.append((pa, pb))
            }
        }
        return connections
    }

    // MARK: - Joint Extraction

    private func extractJoints(
        from observation: VNHumanBodyPoseObservation
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
        ]

        for name in jointNames {
            if let point = try? observation.recognizedPoint(name),
               point.confidence > 0.2 {
                points[name] = point.location
            }
        }

        return points
    }

    // MARK: - Visibility Check

    private func checkVisibility(
        points: [VNHumanBodyPoseObservation.JointName: CGPoint],
        for exercise: ExerciseType
    ) -> Bool {
        let requiredJoints = requiredJointNames(for: exercise)
        let visibleCount = requiredJoints.filter { points[$0] != nil }.count
        return visibleCount >= max(requiredJoints.count - 1, 1)
    }

    private func requiredJointNames(
        for exercise: ExerciseType
    ) -> [VNHumanBodyPoseObservation.JointName] {
        switch exercise {
        case .squats:
            return [.leftShoulder, .rightShoulder, .leftHip, .rightHip] // Need torso length
        case .pushups:
            return [.nose, .leftShoulder, .rightShoulder, .leftHip, .rightHip, .leftAnkle, .rightAnkle]
        case .jumpingJacks:
            return [.leftWrist, .rightWrist, .leftShoulder, .rightShoulder]
        }
    }

    // MARK: - Position Calculation (Direct Y-tracking)

    private func calculatePosition(
        points: [VNHumanBodyPoseObservation.JointName: CGPoint],
        for exercise: ExerciseType
    ) -> CGFloat {
        switch exercise {
        case .squats:
            return calculateSquatPosition(points)
        case .pushups:
            return calculatePushupPosition(points)
        case .jumpingJacks:
            return calculateJumpingJackPosition(points)
        }
    }

    // MARK: - Squat: Track relative hip drop (scale-invariant)

    private func calculateSquatPosition(
        _ points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> CGFloat {
        guard let hip = midpoint(.leftHip, .rightHip, in: points),
              let shoulder = midpoint(.leftShoulder, .rightShoulder, in: points) else {
            return 1.0
        }

        // Torso length acts as our ruler. As you move back, both hip.y and torsoLength shrink proportionally.
        let torsoLength = abs(shoulder.y - hip.y)
        guard torsoLength > 0.05 else { return 1.0 }

        // How many torso-lengths are the hips from the bottom of the frame?
        let normalizedHipHeight = hip.y / torsoLength

        // Calibrate: track highest relative hip height seen (standing)
        if normalizedHipHeight > maxHipY {
            maxHipY = normalizedHipHeight
        }

        guard maxHipY > 0.1 else { return 1.0 }

        let ratio = normalizedHipHeight / maxHipY

        // Amplify: a 30% relative hip drop = full bar travel
        let position = (ratio - 0.70) / 0.30

        return min(max(position, 0.0), 1.0)
    }

    // MARK: - Pushup: Track shoulder descent relative to body length (scale-invariant)

    private func calculatePushupPosition(
        _ points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> CGFloat {
        guard let shoulder = midpoint(.leftShoulder, .rightShoulder, in: points),
              let hip = midpoint(.leftHip, .rightHip, in: points) else {
            return 1.0
        }

        // Use torso length as our scale-invariant ruler (same approach as squats)
        let torsoLength = abs(shoulder.y - hip.y)
        guard torsoLength > 0.03 else { return 1.0 }

        // Normalized shoulder height: how many torso-lengths from the bottom of the frame
        let normalizedShoulderHeight = shoulder.y / torsoLength

        // Calibrate: track highest normalized shoulder position (standing/plank up)
        if normalizedShoulderHeight > maxNoseY {
            maxNoseY = normalizedShoulderHeight
        }

        guard maxNoseY > 0.1 else { return 1.0 }

        let ratio = normalizedShoulderHeight / maxNoseY

        // Amplify: a 20% relative shoulder drop = full bar travel
        let position = (ratio - 0.80) / 0.20

        return min(max(position, 0.0), 1.0)
    }

    // MARK: - Jumping Jack: Track wrist height + ankle spread

    private func calculateJumpingJackPosition(
        _ points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> CGFloat {
        // --- Wrist height signal: BOTH wrists must be above shoulders ---
        var wristScore: CGFloat = 0.0
        if let leftWrist = points[.leftWrist],
           let rightWrist = points[.rightWrist],
           let leftShoulder = points[.leftShoulder],
           let rightShoulder = points[.rightShoulder] {

            // Both wrists must be above their respective shoulders
            let leftAbove = leftWrist.y - leftShoulder.y
            let rightAbove = rightWrist.y - rightShoulder.y
            let minAbove = min(leftAbove, rightAbove) // The lower wrist determines score

            // Require clear overhead raise (not just ambient arm movement)
            // 0.0 = at shoulder level, 0.20 = well above head
            wristScore = min(max(minAbove / 0.15, 0.0), 1.0)
        }

        // --- Ankle spread signal (legs going apart) ---
        var ankleScore: CGFloat = 0.0
        if let leftAnkle = points[.leftAnkle],
           let rightAnkle = points[.rightAnkle],
           let leftShoulder = points[.leftShoulder],
           let rightShoulder = points[.rightShoulder] {
            let ankleSpread = abs(leftAnkle.x - rightAnkle.x)
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            // Require legs 1.5x+ shoulder width apart
            let spreadRatio = ankleSpread / max(shoulderWidth, 0.01)
            ankleScore = min(max((spreadRatio - 1.2) / 0.8, 0.0), 1.0)
        }

        // Combine: 50% wrists + 50% ankles (wrists only if ankles not visible)
        let hasAnkles = points[.leftAnkle] != nil && points[.rightAnkle] != nil
        if hasAnkles {
            return min(max(wristScore * 0.5 + ankleScore * 0.5, 0.0), 1.0)
        } else {
            return min(max(wristScore, 0.0), 1.0)
        }
    }

    // MARK: - Math Helpers

    private func midpoint(
        _ a: VNHumanBodyPoseObservation.JointName,
        _ b: VNHumanBodyPoseObservation.JointName,
        in points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> CGPoint? {
        guard let pa = points[a], let pb = points[b] else { return nil }
        return CGPoint(x: (pa.x + pb.x) / 2.0, y: (pa.y + pb.y) / 2.0)
    }
}
