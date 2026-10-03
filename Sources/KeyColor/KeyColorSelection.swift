import CoreGraphics
import PixelColor

enum KeyColorSelection {
    static func samples(
        from rows: [[PixelColor]],
        maxCount: Int,
        minSaturation: CGFloat,
        minBrightness: CGFloat,
        previousSamples: [KeyColorSample] = [],
        replacementMargin: CGFloat = 0.08
    ) throws -> [KeyColorSample] {
        precondition(maxCount > 0)
        precondition(replacementMargin >= 0 && replacementMargin.isFinite)
        guard let width = rows.first?.count, width > 0 else { return [] }

        var candidates: [KeyColorSample] = []
        for (y, row) in rows.enumerated() {
            try Task.checkCancellation()
            for (x, color) in row.enumerated() {
                guard color.saturation > minSaturation,
                      color.brightness > minBrightness else { continue }
                candidates.append(KeyColorSample(
                    color: color,
                    location: CGPoint(
                        x: (CGFloat(x) + 0.5) / CGFloat(width),
                        y: (CGFloat(y) + 0.5) / CGFloat(rows.count)
                    )
                ))
            }
        }

        var selected: [KeyColorSample] = []
        while selected.count < maxCount {
            try Task.checkCancellation()
            let previous = selected.count < previousSamples.count
                ? previousSamples[selected.count] : nil
            guard let next = nextSample(
                from: candidates,
                selected: selected,
                previous: previous,
                replacementMargin: replacementMargin
            ) else { break }
            selected.append(next)
        }
        return selected
    }

    private static func nextSample(
        from candidates: [KeyColorSample],
        selected: [KeyColorSample],
        previous: KeyColorSample?,
        replacementMargin: CGFloat
    ) -> KeyColorSample? {
        var best: KeyColorSample?
        var bestScore: CGFloat = 0
        var incumbent: KeyColorSample?
        var incumbentScore: CGFloat = 0
        var closestMatch = CGFloat.infinity

        for candidate in candidates {
            let score = selected.isEmpty
                ? candidate.color.saturation
                : selected.reduce(CGFloat.infinity) {
                    min($0, colorDistanceSquared(candidate.color, $1.color))
                }.squareRoot()
            // Never select the same RGB color twice.
            guard selected.isEmpty || score > 0 else { continue }
            // Strict comparison resolves ties in fixed image scan order.
            if best == nil || score > bestScore {
                best = candidate
                bestScore = score
            }

            if let previous {
                let colorDistance = colorDistanceSquared(candidate.color, previous.color)
                // Let a disappeared color be replaced instead of holding stale data.
                guard colorDistance <= 0.25 * 0.25 else { continue }
                let dx = candidate.location.x - previous.location.x
                let dy = candidate.location.y - previous.location.y
                let match = colorDistance + 0.01 * (dx * dx + dy * dy)
                if match < closestMatch {
                    closestMatch = match
                    incumbent = candidate
                    incumbentScore = score
                }
            }
        }

        // Favor the previous palette slot until a challenger wins by the margin.
        if let incumbent, bestScore <= incumbentScore + replacementMargin {
            return incumbent
        }
        return best
    }

    private static func colorDistanceSquared(_ lhs: PixelColor, _ rhs: PixelColor) -> CGFloat {
        let red = lhs.red - rhs.red
        let green = lhs.green - rhs.green
        let blue = lhs.blue - rhs.blue
        return red * red + green * green + blue * blue
    }
}
