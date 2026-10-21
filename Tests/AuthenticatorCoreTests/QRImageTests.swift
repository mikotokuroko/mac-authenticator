import XCTest
import CoreImage
@testable import AuthenticatorCore

final class QRImageTests: XCTestCase {
    func testQRImageToWorkingAccount() throws {
        let uri = "otpauth-migration://offline?data=CiwKFDEyMzQ1Njc4OTAxMjM0NTY3ODkwEgVhbGljZRoHRXhhbXBsZSABKAIwAhABGAIgASgH"
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(uri.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let qr = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let image = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(qr, from: qr.extent) else {
            throw XCTSkip("Core Image cannot render in this execution environment. Run this integration test in a regular macOS session.")
        }
        let payloads = try QRImageReader.payloads(in: image)
        XCTAssertEqual(payloads, [uri])
        let account = try OTPImport.parse(payloads[0]).accounts[0]
        XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: 59)), "94287082")
    }
}
