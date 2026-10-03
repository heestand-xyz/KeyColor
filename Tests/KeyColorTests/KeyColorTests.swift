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

    private func select(_ rows: [[PixelColor]]) throws -> [KeyColorSample] {
        try KeyColorSelection.samples(
            from: rows,
            maxCount: 5,
            minSaturation: 0.25,
            minBrightness: 0.25
        )
    }
}
