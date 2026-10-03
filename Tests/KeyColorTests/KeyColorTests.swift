import CoreGraphics
import PixelColor
import XCTest
@testable import KeyColor

final class KeyColorTests: XCTestCase {
    func testFiveDistinctQualifyingColorsRetainTheirLocations() throws {
        let rows = [
            [PixelColor.red, .green, .blue],
            [PixelColor(red: 1, green: 1, blue: 0), PixelColor(red: 0, green: 1, blue: 1), .white]
        ]
        let samples = try select(rows)

        XCTAssertEqual(samples.count, 5)
        XCTAssertEqual(Set(samples.map { $0.color }).count, 5)
        for sample in samples {
            let x = Int(sample.location.x * 3)
            let y = Int(sample.location.y * 2)
            XCTAssertEqual(sample.color, rows[y][x])
            XCTAssertGreaterThan(sample.color.saturation, 0.25)
            XCTAssertGreaterThan(sample.color.brightness, 0.25)
        }
    }

    func testThresholdsAreStrictAndCoordinatesUsePixelCenters() throws {
        let qualifying = PixelColor(red: 0.5, green: 0, blue: 0)
        let samples = try select([
            [.white, PixelColor(red: 0.25, green: 0, blue: 0)],
            [PixelColor(red: 0.5, green: 0.375, blue: 0.375), qualifying]
        ])

        XCTAssertEqual(samples, [
            KeyColorSample(color: qualifying, location: CGPoint(x: 0.75, y: 0.75))
        ])
    }

    func testUniformSceneReturnsOneColorWithoutLooping() throws {
        let samples = try select([Array(repeating: .red, count: 100)])
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.color, .red)
    }

    func testSceneWithFewerDistinctColorsReturnsAvailableColors() throws {
        let samples = try select([[.red, .blue, .red, .blue]])
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(Set(samples.map { $0.color }), Set([.red, .blue]))
    }

    func testDarkAndDesaturatedScenesReturnNoSamples() throws {
        XCTAssertTrue(try select([[.black, .white, PixelColor(white: 0.5)]]).isEmpty)
        XCTAssertTrue(try select([]).isEmpty)
    }

    func testNearTieKeepsPreviousPaletteOrder() throws {
        let firstRed = PixelColor(red: 1, green: 0.05, blue: 0.05)
        let firstBlue = PixelColor(red: 0.1, green: 0.1, blue: 1)
        let previous = try select([[firstRed, firstBlue]])
        let red = PixelColor(red: 1, green: 0.06, blue: 0.06)
        let blue = PixelColor(red: 0.05, green: 0.05, blue: 1)

        XCTAssertEqual(try select([[red, blue]]).first?.color, blue)
        let stable = try KeyColorSelection.samples(
            from: [[red, blue]], maxCount: 2,
            minSaturation: 0.25, minBrightness: 0.25,
            previousSamples: previous, replacementMargin: 0.08
        )
        XCTAssertEqual(stable.map { $0.color }, [red, blue])
    }

    func testSignificantlyBetterCandidateReplacesPreviousSelection() throws {
        let previous = try select([[
            PixelColor(red: 1, green: 0.05, blue: 0.05),
            PixelColor(red: 0.1, green: 0.1, blue: 1)
        ]])
        let blue = PixelColor.rawBlue
        let samples = try KeyColorSelection.samples(
            from: [[PixelColor(red: 1, green: 0.15, blue: 0.15), blue]],
            maxCount: 2, minSaturation: 0.25, minBrightness: 0.25,
            previousSamples: previous, replacementMargin: 0.08
        )
        XCTAssertEqual(samples.first?.color, blue)
        XCTAssertEqual(samples.count, 2)
    }

    func testMissingPreviousColorIsNotRetained() throws {
        let previous = [KeyColorSample(color: .rawRed, location: CGPoint(x: 0.5, y: 0.5))]
        let samples = try KeyColorSelection.samples(
            from: [[.rawBlue]], maxCount: 1,
            minSaturation: 0.25, minBrightness: 0.25,
            previousSamples: previous
        )
        XCTAssertEqual(samples.first?.color, .rawBlue)
        XCTAssertTrue(try KeyColorSelection.samples(
            from: [[.white]], maxCount: 1,
            minSaturation: 0.25, minBrightness: 0.25,
            previousSamples: previous
        ).isEmpty)
    }

    func testMatchingFavorsPreviousLocationAmongRepeatedColors() throws {
        let location = CGPoint(x: 5.0 / 6.0, y: 0.5)
        let samples = try KeyColorSelection.samples(
            from: [[.rawRed, .rawBlue, .rawRed]], maxCount: 1,
            minSaturation: 0.25, minBrightness: 0.25,
            previousSamples: [KeyColorSample(color: .rawRed, location: location)]
        )
        XCTAssertEqual(samples.first?.location, location)
    }

    func testHistoryAndTieBreakingAreDeterministic() throws {
        let rows: [[PixelColor]] = [[.rawRed, .rawBlue, .rawGreen]]
        let previous = try select(rows)
        let expected = try KeyColorSelection.samples(
            from: rows, maxCount: 3,
            minSaturation: 0.25, minBrightness: 0.25, previousSamples: previous
        )
        for _ in 0..<10 {
            XCTAssertEqual(try KeyColorSelection.samples(
                from: rows, maxCount: 3,
                minSaturation: 0.25, minBrightness: 0.25, previousSamples: previous
            ), expected)
        }
    }

    func testLocationFilterMovesPartwayTowardNewSample() {
        var filter = KeyColorFilter(colorResponse: 1, locationResponse: 0.2)
        filter.update(with: [KeyColorSample(color: .rawRed, location: .zero)])
        let samples = filter.update(with: [
            KeyColorSample(color: .rawBlue, location: CGPoint(x: 1, y: 1))
        ])
        XCTAssertEqual(samples.first?.location, CGPoint(x: 0.2, y: 0.2))
        XCTAssertEqual(samples.first?.color, .rawBlue)
    }

    func testColorFilterWrapsHueAndPreservesVividness() throws {
        var filter = KeyColorFilter(colorResponse: 0.5, locationResponse: 1)
        filter.update(with: [
            KeyColorSample(color: PixelColor(hue: 0.98, saturation: 0.8, brightness: 0.7), location: .zero)
        ])
        let sample = try XCTUnwrap(filter.update(with: [
            KeyColorSample(color: PixelColor(hue: 0.02, saturation: 0.6, brightness: 0.5), location: .zero)
        ]).first)
        XCTAssertLessThan(min(sample.color.hue, 1 - sample.color.hue), 0.0001)
        XCTAssertEqual(sample.color.saturation, 0.7, accuracy: 0.0001)
        XCTAssertEqual(sample.color.brightness, 0.6, accuracy: 0.0001)

        filter.reset()
        filter.update(with: [KeyColorSample(color: .rawRed, location: .zero)])
        let complementary = try XCTUnwrap(filter.update(with: [
            KeyColorSample(color: .rawCyan, location: .zero)
        ]).first)
        XCTAssertEqual(complementary.color.saturation, 1, accuracy: 0.0001)
        XCTAssertEqual(complementary.color.brightness, 1, accuracy: 0.0001)
    }

    func testFilterClearsLostSamplesAndResetsHistory() {
        var filter = KeyColorFilter()
        let red = KeyColorSample(color: .rawRed, location: .zero)
        let blue = KeyColorSample(color: .rawBlue, location: CGPoint(x: 1, y: 1))
        filter.update(with: [red, blue])
        XCTAssertEqual(filter.update(with: [red]).count, 1)
        XCTAssertTrue(filter.update(with: []).isEmpty)
        XCTAssertEqual(filter.update(with: [blue]), [blue])
        filter.reset()
        XCTAssertEqual(filter.update(with: [red]), [red])
    }

    private func select(_ rows: [[PixelColor]]) throws -> [KeyColorSample] {
        try KeyColorSelection.samples(
            from: rows,
            maxCount: 5,
            minSaturation: 0.25,
            minBrightness: 0.25
        )
    }
}
