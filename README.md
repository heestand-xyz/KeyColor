![Example Key Colors from Images](https://github.com/heestand-xyz/KeyColor/blob/main/Assets/KeyColor.png?raw=true)

# Key Color

Find key colors in images.

## Install

```swift
.package(url: "https://github.com/heestand-xyz/KeyColor", from: "1.0.1")
```

## Example

```swift
guard let image = UIImage(named: "My Image") else { return }
let color: Color? = try await image.keyColor()
let colors: [Color] = try await image.keyColors(3)
```

> If the image is monochrome no colors will be returned.

> The default saturation and brightness thresholds are at 50%.

## Functions

### SwiftUI Color

```swift
extension UIImage {
    
    func keyColor(
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> Color?
    
    func keyColors(
        _ maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [Color]
}
```

> Both UIImage and NSImage are supported.

### PixelColor

```swift
extension Graphic {
    
    func keyPixelColor(
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> PixelColor?
    
    func keyPixelColors(
        _ maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [PixelColor]
}
```

### Color locations

Use a live `Graphic` directly to get colors and the pixels they came from:

```swift
let samples = try await graphic.keyColorSamples(
    5,
    minSaturation: 0.25,
    minBrightness: 0.25
)
for sample in samples {
    let color = sample.color.color
    let point = sample.location
}
```

Each `KeyColorSample` contains a `PixelColor` and a normalized `CGPoint`.
Coordinates run from the top-left `(0, 0)` to the bottom-right `(1, 1)` and
refer to pixel centers in the sampled image. They remain normalized when
the image is downsampled. Thresholds are strict; only colors above both
minimums qualify. The selector returns fewer than the requested count
when the image has fewer distinct qualifying colors.

> Powered by [PixelColor](https://github.com/heestand-xyz/PixelColor) and [AsyncGraphics](https://github.com/heestand-xyz/AsyncGraphics)
