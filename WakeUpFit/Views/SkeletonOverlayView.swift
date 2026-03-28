import SwiftUI
import Vision

/// Debug overlay that draws skeleton lines and joint dots on the camera feed
struct SkeletonOverlayView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let connections: [(CGPoint, CGPoint)]
    let position: CGFloat
    let phase: String

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            // Draw connections (bones)
            ForEach(0..<connections.count, id: \.self) { i in
                let (a, b) = connections[i]
                let pointA = visionToScreen(a, in: size)
                let pointB = visionToScreen(b, in: size)

                Path { path in
                    path.move(to: pointA)
                    path.addLine(to: pointB)
                }
                .stroke(Theme.primary.opacity(0.7), lineWidth: 2.5)
            }

            // Draw joints (dots)
            ForEach(Array(joints.values.enumerated()), id: \.offset) { _, point in
                let screenPoint = visionToScreen(point, in: size)
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 8, height: 8)
                    .position(screenPoint)
            }

        }
    }

    /// Convert Vision coordinates to screen coordinates.
    /// Vision: origin bottom-left, normalized 0-1 (in the portrait buffer space).
    /// Screen: origin top-left.
    /// The preview layer auto-mirrors the front camera, so we mirror X here to match.
    private func visionToScreen(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (1.0 - point.x) * size.width,   // Mirror X to match preview's front-camera mirror
            y: (1.0 - point.y) * size.height    // Flip Y (Vision=bottom-up, Screen=top-down)
        )
    }
}
