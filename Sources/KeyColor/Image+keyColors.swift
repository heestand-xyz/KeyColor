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
        .map { $0.color }
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
        try await keyColorSamples(
            maxCount,
            minSaturation: minSaturation,
            minBrightness: minBrightness,
            resolution: resolution,
            interpolation: interpolation
        ).map { $0.color }
    }

    /// Selects distinct key colors while retaining their normalized image locations.
    /// Returns fewer samples when fewer distinct colors pass the thresholds.
    public func keyColorSamples(
        _ maxCount: Int,
        minSaturation: CGFloat = 0.5,
        minBrightness: CGFloat = 0.5,
        resolution: CGSize? = CGSize(width: 100, height: 100),
        interpolation: Graphic.ResolutionInterpolation = .lanczos
    ) async throws -> [KeyColorSample] {
        precondition(maxCount > 0)
        try Task.checkCancellation()

        var graphic: Graphic = self
        if let resolution {
            precondition(resolution.width > 0 && resolution.height > 0)
            let sampleResolution = graphic.resolution.place(in: resolution, placement: .fit)
            if sampleResolution.width < graphic.width || sampleResolution.height < graphic.height {
                graphic = try await graphic.resized(to: sampleResolution, interpolation: interpolation)
            }
        }

        let rows = try await graphic.pixelColors
        return try KeyColorSelection.samples(
            from: rows,
            maxCount: maxCount,
            minSaturation: minSaturation,
            minBrightness: minBrightness
        )
    }
}
