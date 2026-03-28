import Foundation

enum ExerciseType: String, CaseIterable, Identifiable {
    case pushups
    case squats
    case jumpingJacks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pushups: return "Push-Ups"
        case .squats: return "Squats"
        case .jumpingJacks: return "Jumping Jacks"
        }
    }

    var icon: String {
        switch self {
        case .pushups: return "figure.strengthtraining.traditional"
        case .squats: return "figure.cooldown"
        case .jumpingJacks: return "figure.jumprope"
        }
    }

    var defaultReps: Int { 5 }

    /// The joints required to be visible for this exercise
    var requiredJointGroups: [JointGroup] {
        switch self {
        case .pushups:
            return [.upperBody, .arms]
        case .squats:
            return [.upperBody, .legs]
        case .jumpingJacks:
            return [.upperBody, .arms, .legs]
        }
    }

    enum JointGroup {
        case upperBody  // nose, neck, shoulders
        case arms       // elbows, wrists
        case legs       // hips, knees, ankles
    }
}
