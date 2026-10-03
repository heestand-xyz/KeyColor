import CoreGraphics
import PixelColor

/// A low-pass filter for an ordered, temporally stable palette of samples.
public struct KeyColorFilter: Sendable {
    public private(set) var samples: [KeyColorSample] = []

    /// Fraction of the new color applied per update, in 0...1.
    public let colorResponse: CGFloat
    /// Fraction of the new location applied per update, in 0...1.
    public let locationResponse: CGFloat

    public init(colorResponse: CGFloat = 0.25, locationResponse: CGFloat = 0.2) {
        precondition((0...1).contains(colorResponse))
        precondition((0...1).contains(locationResponse))
        self.colorResponse = colorResponse
        self.locationResponse = locationResponse
    }

    @discardableResult
    public mutating func update(with newSamples: [KeyColorSample]) -> [KeyColorSample] {
        let previousSamples = samples
        samples = newSamples.enumerated().map { index, sample in
            guard index < previousSamples.count else { return sample }
            let previous = previousSamples[index]
            let color: PixelColor
            if colorResponse == 1 {
                color = sample.color
            } else if colorResponse == 0 || previous.color == sample.color {
                color = previous.color
            } else {
                // Follow the shortest path around the hue wheel. Filtering HSV
                // preserves qualifying saturation/brightness between samples.
                var hueDelta = sample.color.hue - previous.color.hue
                if hueDelta > 0.5 { hueDelta -= 1 }
                if hueDelta < -0.5 { hueDelta += 1 }
                color = PixelColor(
                    hue: previous.color.hue + hueDelta * colorResponse,
                    saturation: previous.color.saturation
                        + (sample.color.saturation - previous.color.saturation) * colorResponse,
                    brightness: previous.color.brightness
                        + (sample.color.brightness - previous.color.brightness) * colorResponse,
                    opacity: previous.color.opacity
                        + (sample.color.opacity - previous.color.opacity) * colorResponse
                )
            }
            return KeyColorSample(
                color: color,
                location: CGPoint(
                    x: previous.location.x + (sample.location.x - previous.location.x) * locationResponse,
                    y: previous.location.y + (sample.location.y - previous.location.y) * locationResponse
                )
            )
        }
        return samples
    }

    public mutating func reset() {
        samples = []
    }
}
