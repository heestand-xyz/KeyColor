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

> Powered by [PixelColor](https://github.com/heestand-xyz/PixelColor) and [AsyncGraphics](https://github.com/heestand-xyz/AsyncGraphics)
