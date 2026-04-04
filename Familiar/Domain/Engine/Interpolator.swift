public enum Interpolator {
    public static func value(start: Int, end: Int, step: Int, totalSteps: Int) -> Int {
        guard totalSteps > 0 else { return start }
        return start + (end - start) * step / totalSteps
    }

    public static func movement(start: Int, end: Int, step: Int, totalSteps: Int) -> Int {
        guard totalSteps > 1 else { return start }
        return start + (end - start) * step / (totalSteps - 1)
    }
}
