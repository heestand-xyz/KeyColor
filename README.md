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

### Stable live colors

Pass the previous **unfiltered** selections back into the sampler to retain
palette order and nearby locations until another candidate wins by a meaningful
margin. The match must be within 0.25 RGB distance of the previous color; missing
colors are replaced by current qualifying pixels. Exact ties use image scan
order, so the same image and history always give the same result.

Then low-pass filter the selected colors and locations independently:

```swift
var previous: [KeyColorSample] = []
var filter = KeyColorFilter(colorResponse: 0.25, locationResponse: 0.2)

// For each live graphic:
let samples = try await graphic.keyColorSamples(
    5,
    minSaturation: 0.25,
    minBrightness: 0.25,
    previousSamples: previous,
    replacementMargin: 0.08
)
previous = samples
let displayedSamples = filter.update(with: samples)
```

The replacement margin is measured in saturation for the first palette slot,
and RGB distance from the selected palette for subsequent slots. Passing no
history performs ordinary selection. Smaller filter response values give
smoother, slower updates; 1 follows each sample immediately. Color filtering
uses the shortest hue path and averages saturation and brightness separately,
preserving their thresholds without mixing complementary colors into gray.
Reset the history and filter when the source changes or rotates.

> Powered by [PixelColor](https://github.com/heestand-xyz/PixelColor) and [AsyncGraphics](https://github.com/heestand-xyz/AsyncGraphics)
