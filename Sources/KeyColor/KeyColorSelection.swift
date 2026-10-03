import CoreGraphics
import PixelColor

enum KeyColorSelection {
    static func samples(
        from rows: [[PixelColor]],
        maxCount: Int,
        minSaturation: CGFloat,
        minBrightness: CGFloat
    ) throws -> [KeyColorSample] {
        precondition(maxCount > 0)
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

        guard let primary = candidates.max(by: {
            $0.color.saturation < $1.color.saturation
        }) else { return [] }

        var selected = [primary]
        while selected.count < maxCount {
            try Task.checkCancellation()
            var farthest: KeyColorSample?
            var greatestDistance: CGFloat = 0
            for candidate in candidates {
                let distance = selected.reduce(CGFloat.infinity) { closest, sample in
                    let red = candidate.color.red - sample.color.red
                    let green = candidate.color.green - sample.color.green
                    let blue = candidate.color.blue - sample.color.blue
                    return min(closest, red * red + green * green + blue * blue)
                }
                if distance > greatestDistance {
                    greatestDistance = distance
                    farthest = candidate
                }
            }
            // A scene can have fewer distinct qualifying colors than requested.
            guard let farthest else { break }
            selected.append(farthest)
        }
        return selected
    }
}
