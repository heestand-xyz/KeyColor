import CoreGraphics
import PixelColor

/// A population-weighted representative, rather than a single extreme pixel.
struct DistinctColorCandidate {
    let sample: KeyColorSample
    let population: CGFloat
}

enum DistinctKeyColorSelection {
    static func samples(
        from candidates: [DistinctColorCandidate],
        maxCount: Int,
        minimumCoverage: CGFloat,
        previousSamples: [KeyColorSample],
        replacementMargin: CGFloat
    ) throws -> [KeyColorSample] {
        guard let largest = candidates.map(\.population).max(), largest > 0 else { return [] }
        let total = candidates.reduce(0) { $0 + $1.population }
        // Relative coverage rejects sensor speckles, while small images still work.
        let eligible = candidates.filter { $0.population / total >= minimumCoverage }
        var selected: [KeyColorSample] = []
        while selected.count < maxCount {
            try Task.checkCancellation()
            let ranked = eligible.compactMap { candidate -> (KeyColorSample, CGFloat)? in
                let diversity = selected.reduce(CGFloat(1)) {
                    min($0, distance(candidate.sample.color, $1.color))
                }
                guard selected.isEmpty || diversity > 0.12 else { return nil }
                // A fourth root keeps a visible minority hue competitive with broad backgrounds.
                // Quadratic saturation weighting gives vivid groups more priority over muted ones.
                let saturation = min(candidate.sample.color.saturation, 1)
                let brightness = min(candidate.sample.color.brightness, 1)
                let hueSeparation = selected.reduce(CGFloat(1)) {
                    let gap = abs(candidate.sample.color.hue - $1.color.hue)
                    return min($0, min(gap, 1 - gap))
                }
                // Favor another hue family over additional shades of an already represented hue.
                let hueCoverage = 0.15 + 0.85 * min(hueSeparation * 12, 1)
                let significance = pow(candidate.population / largest, 0.25)
                    * (0.15 + 0.85 * saturation * saturation)
                    * (0.25 + 0.75 * brightness)
                return (candidate.sample, significance * diversity * hueCoverage)
            }
            guard let best = ranked.max(by: { $0.1 < $1.1 }) else { break }
            var next = best
            if selected.count < previousSamples.count {
                let previous = previousSamples[selected.count]
                if let incumbent = ranked.min(by: {
                    distance($0.0.color, previous.color) < distance($1.0.color, previous.color)
                }), distance(incumbent.0.color, previous.color) < 0.2,
                   best.1 <= incumbent.1 + replacementMargin {
                    next = incumbent
                }
            }
            selected.append(next.0)
        }
        return selected
    }

    /// Hue distance fades toward neutral, and HDR brightness remains unbounded in samples.
    private static func distance(_ lhs: PixelColor, _ rhs: PixelColor) -> CGFloat {
        let left = vector(lhs)
        let right = vector(rhs)
        let dx = left.x - right.x
        let dy = left.y - right.y
        let dz = left.z - right.z
        return (dx * dx + dy * dy + dz * dz).squareRoot() / 2
    }

    private static func vector(_ color: PixelColor) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        // Extended-gamut channels can be negative; match the GPU's classification.
        let positive = PixelColor(red: max(color.red, 0), green: max(color.green, 0), blue: max(color.blue, 0))
        let angle = positive.hue * 2 * .pi
        return (
            positive.saturation * cos(angle),
            positive.saturation * sin(angle),
            2 * positive.brightness / (1 + positive.brightness)
        )
    }
}
