import AsyncGraphics
import CoreGraphics
import Foundation
import Metal
import PixelColor

extension Graphic {
    /// Selects distinct, populated hue/brightness groups from every source pixel on the GPU.
    /// Colors are saturation-weighted group averages, with normalized group centroid locations.
    /// HDR RGB values are retained. No resizing or CPU pixel-array readback is performed.
    /// Pass unfiltered history to favor a current group until a challenger wins by the margin.
    public func distinctKeyColorSamples(
        count: Int,
        minSaturation: CGFloat = 0.1,
        minBrightness: CGFloat = 0.1,
        minimumCoverage: CGFloat = 0.002,
        previousSamples: [KeyColorSample] = [],
        replacementMargin: CGFloat = 0.08
    ) async throws -> [KeyColorSample] {
        precondition(count > 0)
        precondition(minimumCoverage.isFinite && (0...1).contains(minimumCoverage))
        precondition(replacementMargin.isFinite && replacementMargin >= 0)
        try Task.checkCancellation()
        let candidates = try await DistinctColorHistogram.shared.candidates(
            from: self, minSaturation: minSaturation, minBrightness: minBrightness
        )
        try Task.checkCancellation()
        return try DistinctKeyColorSelection.samples(
            from: candidates,
            maxCount: count,
            minimumCoverage: minimumCoverage,
            previousSamples: previousSamples,
            replacementMargin: replacementMargin
        )
    }
}

/// Actor ownership protects cached pipelines. Each invocation owns its buffers through GPU completion.
private actor DistinctColorHistogram {
    static let shared = DistinctColorHistogram()
    private let binCount = 96
    private var device: MTLDevice?
    private var histogram: MTLComputePipelineState?
    private var reduction: MTLComputePipelineState?
    private var queue: MTLCommandQueue?

    private struct Parameters {
        var minSaturation: Float
        var minBrightness: Float
        var partitions: UInt32
        var padding: UInt32 = 0
    }

    private struct Bin {
        var rgbCount: SIMD4<Float>
        var xyWeight: SIMD4<Float>
    }

    private enum HistogramError: Error {
        case unavailable
    }

    func candidates(
        from graphic: Graphic, minSaturation: CGFloat, minBrightness: CGFloat
    ) async throws -> [DistinctColorCandidate] {
        let texture = graphic.texture
        if device !== texture.device {
            let library = try texture.device.makeDefaultLibrary(bundle: .module)
            guard let histogramFunction = library.makeFunction(name: "distinctColorHistogram"),
                  let reductionFunction = library.makeFunction(name: "distinctColorReduction"),
                  let queue = texture.device.makeCommandQueue() else { throw HistogramError.unavailable }
            let newHistogram = try await texture.device.makeComputePipelineState(function: histogramFunction)
            let newReduction = try await texture.device.makeComputePipelineState(function: reductionFunction)
            histogram = newHistogram
            reduction = newReduction
            self.queue = queue
            device = texture.device
        }
        guard let histogram, let reduction, let queue else { throw HistogramError.unavailable }
        let partitions = min(1024, texture.width * texture.height)
        var parameters = Parameters(
            minSaturation: Float(minSaturation), minBrightness: Float(minBrightness),
            partitions: UInt32(partitions)
        )
        guard let partials = texture.device.makeBuffer(
            length: partitions * binCount * MemoryLayout<Bin>.stride, options: .storageModePrivate
        ), let output = texture.device.makeBuffer(
            length: binCount * MemoryLayout<Bin>.stride, options: .storageModeShared
        ), let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else {
            throw HistogramError.unavailable
        }
        encoder.setComputePipelineState(histogram)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(partials, offset: 0, index: 0)
        encoder.setBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 1)
        encoder.dispatchThreads(
            MTLSize(width: partitions, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: min(128, histogram.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        )
        encoder.setComputePipelineState(reduction)
        encoder.setBuffer(partials, offset: 0, index: 0)
        encoder.setBuffer(output, offset: 0, index: 1)
        encoder.setBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 2)
        encoder.dispatchThreads(
            MTLSize(width: binCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: min(32, reduction.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        )
        encoder.endEncoding()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            command.addCompletedHandler { completed in
                if let error = completed.error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
            command.commit()
        }
        try Task.checkCancellation()
        let bins = output.contents().bindMemory(to: Bin.self, capacity: binCount)
        return (0..<binCount).compactMap { index in
            let bin = bins[index]
            let count = bin.rgbCount.w
            let weight = bin.xyWeight.z
            guard count > 0, weight > 0 else { return nil }
            return DistinctColorCandidate(
                sample: KeyColorSample(
                    color: PixelColor(
                        red: CGFloat(bin.rgbCount.x / weight),
                        green: CGFloat(bin.rgbCount.y / weight),
                        blue: CGFloat(bin.rgbCount.z / weight)
                    ),
                    location: CGPoint(x: CGFloat(bin.xyWeight.x / count), y: CGFloat(bin.xyWeight.y / count))
                ),
                population: CGFloat(count)
            )
        }
    }
}
