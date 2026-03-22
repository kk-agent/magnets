import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Magnets

final class SharedMediaStoreTests: XCTestCase {

    // MARK: - saveImageData

    func testSaveImageDataReturnsRelativePathWithFileName() throws {
        let imageData = try Self.makeMinimalJPEG()
        let relativePath = try SharedMediaStore.saveImageData(imageData)

        XCTAssertTrue(relativePath.hasPrefix("Media/"), "Expected path to start with Media/")
        XCTAssertTrue(relativePath.hasSuffix(".jpeg") || relativePath.hasSuffix(".jpg"),
                       "Expected JPEG extension, got \(relativePath)")
    }

    func testSaveImageDataPreservesPNGExtension() throws {
        let imageData = try Self.makeMinimalPNG()
        let relativePath = try SharedMediaStore.saveImageData(imageData)

        XCTAssertTrue(relativePath.hasSuffix(".png"),
                       "Expected .png extension, got \(relativePath)")
    }

    func testSavedFileExistsOnDisk() throws {
        let imageData = try Self.makeMinimalJPEG()
        let relativePath = try SharedMediaStore.saveImageData(imageData)
        let fileURL = SharedMediaStore.fileURL(for: relativePath)

        XCTAssertNotNil(fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL!.path))
    }

    func testSavedFileContentsMatchInput() throws {
        let imageData = try Self.makeMinimalJPEG()
        let relativePath = try SharedMediaStore.saveImageData(imageData)
        let fileURL = SharedMediaStore.fileURL(for: relativePath)!
        let readBack = try Data(contentsOf: fileURL)

        XCTAssertEqual(readBack, imageData)
    }

    // MARK: - fileURL

    func testFileURLReturnsNilForNilPath() {
        XCTAssertNil(SharedMediaStore.fileURL(for: nil))
    }

    func testFileURLReturnsNilForEmptyPath() {
        XCTAssertNil(SharedMediaStore.fileURL(for: ""))
    }

    func testFileURLReturnsValidURLForPath() {
        let url = SharedMediaStore.fileURL(for: "Media/test.jpg")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.contains("Media/test.jpg"))
    }

    // MARK: - loadCGImage round-trip

    func testLoadCGImageRoundTrip() throws {
        let imageData = try Self.makeMinimalPNG()
        let relativePath = try SharedMediaStore.saveImageData(imageData)

        let cgImage = SharedMediaStore.loadCGImage(from: relativePath)
        XCTAssertNotNil(cgImage, "Should load back the saved image")
        XCTAssertEqual(cgImage?.width, 1)
        XCTAssertEqual(cgImage?.height, 1)
    }

    func testLoadCGImageWithThumbnail() throws {
        let imageData = try Self.make10x10PNG()
        let relativePath = try SharedMediaStore.saveImageData(imageData)

        let thumb = SharedMediaStore.loadCGImage(from: relativePath, maxPixelSize: 5)
        XCTAssertNotNil(thumb, "Should load a thumbnail")
        XCTAssertLessThanOrEqual(thumb!.width, 5)
        XCTAssertLessThanOrEqual(thumb!.height, 5)
    }

    func testLoadCGImageReturnsNilForMissingFile() {
        XCTAssertNil(SharedMediaStore.loadCGImage(from: "Media/nonexistent-abc123.png"))
    }

    func testLoadCGImageReturnsNilForNilPath() {
        XCTAssertNil(SharedMediaStore.loadCGImage(from: nil))
    }

    // MARK: - Helpers

    /// Generate minimal valid JPEG data (1×1 red pixel).
    private static func makeMinimalJPEG() throws -> Data {
        try makeImageData(type: UTType.jpeg.identifier, width: 1, height: 1)
    }

    /// Generate minimal valid PNG data (1×1 red pixel).
    private static func makeMinimalPNG() throws -> Data {
        try makeImageData(type: UTType.png.identifier, width: 1, height: 1)
    }

    /// Generate a 10×10 PNG for thumbnail tests.
    private static func make10x10PNG() throws -> Data {
        try makeImageData(type: UTType.png.identifier, width: 10, height: 10)
    }

    private static func makeImageData(type: String, width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "TestHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create CGContext"])
        }

        // Fill with red
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "TestHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create CGImage"])
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type as CFString, 1, nil) else {
            throw NSError(domain: "TestHelper", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create image destination"])
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "TestHelper", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot finalize image"])
        }

        return data as Data
    }
}
