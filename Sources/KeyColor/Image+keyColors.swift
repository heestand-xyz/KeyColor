import SwiftUI
import CoreGraphics
import AsyncGraphics
import TextureMap
import PixelColor

extension TMImage {
    
    public func keyColors(
        maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        at resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [Color] {
        try await keyPixelColors(
            maxCount: maxCount,
            minSaturation: minSaturation,
            minBrightness: minBrightness,
            at: resolution,
            interpolation: interpolation
        )
        .map { color in
            color.color
        }
    }
    
    public func keyPixelColors(
        maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        at resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [PixelColor] {
        try await Graphic.image(self)
            .keyPixelColors(
                maxCount: maxCount,
                minSaturation: minSaturation,
                minBrightness: minBrightness,
                at: resolution,
                interpolation: interpolation
            )
    }
}

extension Graphic {
    
    public func keyColors(
        maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        at resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [Color] {
        try await keyPixelColors(
            maxCount: maxCount,
            minSaturation: minSaturation,
            minBrightness: minBrightness,
            at: resolution,
            interpolation: interpolation
        )
        .map { color in
            color.color
        }
    }
    
    public func keyPixelColors(
        maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        at resolution: CGSize? = CGSize(width: 100, height: 100),
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
