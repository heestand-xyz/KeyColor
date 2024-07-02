import SwiftUI
import CoreGraphics
import AsyncGraphics
import TextureMap
import PixelColor

extension TMImage {
    
    public func keyColor(
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> Color? {
        try await keyColors(
            1,
            minSaturation: minSaturation,
            minBrightness: minBrightness,
            resolution: resolution,
            interpolation: interpolation
        ).first
    }
    
    public func keyColors(
        _ maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [Color] {
        let graphic: Graphic = try await .image(self)
        return try await graphic.keyPixelColors(
            maxCount,
            minSaturation: minSaturation,
            minBrightness: minBrightness,
            resolution: resolution,
            interpolation: interpolation
        )
        .map { color in
            color.color
        }
    }
}

extension Graphic {
    
    public func keyPixelColor(
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> PixelColor? {
        try await keyPixelColors(
            1,
            minSaturation: minSaturation,
            minBrightness: minBrightness,
            resolution: resolution,
            interpolation: interpolation
        ).first
    }
    
    public func keyPixelColors(
        _ maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [PixelColor] {
        precondition(maxCount > 0)
        
        var graphic: Graphic = self
        if let resolution: CGSize {
            let sampleResolution: CGSize = graphic.resolution.place(in: resolution, placement: .fit)
            if sampleResolution.height < graphic.resolution.height {
                graphic = try await graphic.resized(to: sampleResolution, interpolation: interpolation)
            }
        }
        
        let colors: [PixelColor] = try await graphic.pixelColors.flatMap({ $0 })
            .filter({ $0.saturation > minSaturation })
            .filter({ $0.brightness > minBrightness })
        if colors.count <= maxCount {
            return colors
        }
        
        var keyColors: [PixelColor] = []
        
        let primaryColor: PixelColor = colors.sorted(by: { $0.saturation > $1.saturation }).first!
        keyColors.append(primaryColor)
        
        while keyColors.count < maxCount {
            var maxDistance = 0.0
            var farthestColor: PixelColor? = nil
            for color in colors {
                let minDistance = keyColors.map { keyColor in
                    sqrt(
                        pow(color.red - keyColor.red, 2) +
                        pow(color.green - keyColor.green, 2) +
                        pow(color.blue - keyColor.blue, 2)
                    )
                }.min() ?? 0.0
                if minDistance > maxDistance {
                    maxDistance = minDistance
                    farthestColor = color
                }
            }
            if let farthestColor = farthestColor {
                keyColors.append(farthestColor)
            }
        }
        
        return keyColors
    }
}
