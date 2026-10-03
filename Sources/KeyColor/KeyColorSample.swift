import CoreGraphics
import PixelColor

/// A selected color and the location of the sampled pixel in the image.
public struct KeyColorSample: Equatable, Sendable {
    public let color: PixelColor

    /// Normalized coordinates: (0, 0) is the top-left, (1, 1) is the bottom-right.
    public let location: CGPoint

    public init(color: PixelColor, location: CGPoint) {
        self.color = color
        self.location = location
    }
}
