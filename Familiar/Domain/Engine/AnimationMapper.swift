public enum AnimationMapper {
    public static func resolve(
        mood: String,
        config: AnimationConfig,
        animations: [Int: Animation]
    ) -> Int? {
        let names = config.moods[mood] ?? config.moods["chill"] ?? ["walk"]
        return pickAnimation(from: names, in: animations)
    }

    public static func resolveEvent(
        event: String,
        config: AnimationConfig,
        animations: [Int: Animation]
    ) -> Int? {
        guard let names = config.events[event] else { return nil }
        return pickAnimation(from: names, in: animations)
    }

    private static func pickAnimation(
        from names: [String],
        in animations: [Int: Animation]
    ) -> Int? {
        guard let name = names.randomElement() else { return nil }
        return animations.values.first(where: { $0.name == name })?.id
    }
}
