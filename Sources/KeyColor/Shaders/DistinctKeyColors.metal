#include <metal_stdlib>
using namespace metal;

// Hue wraps at red; brightness is compressed only for grouping, never for output.
constant uint hueCount = 24;
constant uint binCount = hueCount * 4 * 3;

struct ColorBin {
    float4 rgbCount;
    float4 xyWeight;
};

struct Parameters {
    float minSaturation;
    float minBrightness;
    uint partitions;
    uint padding;
};

kernel void distinctColorHistogram(
    texture2d<float, access::read> image [[texture(0)]],
    device ColorBin* partials [[buffer(0)]],
    constant Parameters& parameters [[buffer(1)]],
    uint partition [[thread_position_in_grid]]
) {
    if (partition >= parameters.partitions) return;
    device ColorBin* bins = partials + partition * binCount;
    for (uint bin = 0; bin < binCount; ++bin) {
        bins[bin].rgbCount = 0;
        bins[bin].xyWeight = 0;
    }
    uint width = image.get_width();
    uint height = image.get_height();
    // Every source pixel participates; no resize or interpolated colors.
    for (uint pixel = partition; pixel < width * height; pixel += parameters.partitions) {
        uint2 position = uint2(pixel % width, pixel / width);
        float4 rgba = image.read(position);
        if (!all(isfinite(rgba)) || rgba.a <= 0) continue;
        float3 rgb = max(rgba.rgb, 0.0);
        float high = max(rgb.r, max(rgb.g, rgb.b));
        float low = min(rgb.r, min(rgb.g, rgb.b));
        float chroma = high - low;
        float saturation = high > 0 ? chroma / high : 0;
        if (saturation <= parameters.minSaturation || high <= parameters.minBrightness) continue;
        float hue = 0;
        if (chroma > 0) {
            if (high == rgb.r) hue = (rgb.g - rgb.b) / chroma;
            else if (high == rgb.g) hue = (rgb.b - rgb.r) / chroma + 2;
            else hue = (rgb.r - rgb.g) / chroma + 4;
            hue = fract(hue / 6 + 1);
        }
        uint hueBin = uint(floor(hue * hueCount + 0.5)) % hueCount;
        uint brightnessBin = min(uint(high / (1 + high) * 4), 3u);
        uint saturationBin = min(uint(saturation * 3), 2u);
        uint bin = (brightnessBin * 3 + saturationBin) * hueCount + hueBin;
        float weight = 0.25 + 0.75 * saturation;
        bins[bin].rgbCount += float4(rgba.rgb * weight, 1);
        bins[bin].xyWeight += float4((float2(position) + 0.5) / float2(width, height), weight, 0);
    }
}

kernel void distinctColorReduction(
    const device ColorBin* partials [[buffer(0)]],
    device ColorBin* output [[buffer(1)]],
    constant Parameters& parameters [[buffer(2)]],
    uint bin [[thread_position_in_grid]]
) {
    if (bin >= binCount) return;
    ColorBin sum = { float4(0), float4(0) };
    for (uint partition = 0; partition < parameters.partitions; ++partition) {
        ColorBin value = partials[partition * binCount + bin];
        sum.rgbCount += value.rgbCount;
        sum.xyWeight += value.xyWeight;
    }
    output[bin] = sum;
}
