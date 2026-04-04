public enum TransitionPicker {
    public static func pick(from candidates: [NextAnim], context: BorderType) -> Int? {
        let eligible = candidates.filter { $0.only.rawValue & context.rawValue != 0 }
        guard !eligible.isEmpty else { return nil }

        let totalProb = eligible.reduce(0) { $0 + $1.probability }
        guard totalProb > 0 else { return nil }

        var roll = Int.random(in: 1 ... totalProb)
        for candidate in eligible {
            roll -= candidate.probability
            if roll <= 0 { return candidate.animationId }
        }
        return eligible.last?.animationId
    }
}
