import XCTest
@testable import AuthenticatorCore
final class ImportTests: XCTestCase {
    func testStandardURIProducesKnownCode() throws {
        let result = try OTPImport.parse("otpauth://totp/Example:alice?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Example&digits=8")
        XCTAssertEqual(result.accounts.first?.issuer, "Example")
        XCTAssertEqual(result.accounts.first?.name, "alice")
        XCTAssertEqual(result.accounts.first?.code(at: Date(timeIntervalSince1970: 59)), "94287082")
    }
}

extension ImportTests {
    // Hand-encoded protobuf fixture from the published export schema; dummy RFC key only.
    private var migrationFixture: String { "CiwKFDEyMzQ1Njc4OTAxMjM0NTY3ODkwEgVhbGljZRoHRXhhbXBsZSABKAIwAhABGAIgASgH" }
    func testGoogleExportAndSplitBatch() throws {
        let result = try OTPImport.parse("otpauth-migration://offline?data=" + migrationFixture)
        XCTAssertEqual(result.accounts.count, 1)
        XCTAssertEqual(result.batchIndex, 1)
        XCTAssertEqual(result.batchSize, 2)
        XCTAssertEqual(result.accounts[0].name, "alice")
        XCTAssertEqual(result.accounts[0].issuer, "Example")
        XCTAssertEqual(result.accounts[0].code(at: Date(timeIntervalSince1970: 59)), "94287082")
    }
    func testReimportRecognisesSameCredentialDespiteFreshIdentifier() throws {
        let first = try OTPImport.parse("otpauth-migration://offline?data=" + migrationFixture).accounts[0]
        let second = try OTPImport.parse("otpauth-migration://offline?data=" + migrationFixture).accounts[0]
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertTrue(first.isSameCredential(as: second))
    }
    func testUnsupportedAndMalformedURIRejected() {
        for text in [
            "https://example.com", "otpauth://hotp/a?secret=MY",
            "otpauth://totp/a?secret=INVALID!", "otpauth://totp/a?secret=MZ", // non-zero unused bits
            "otpauth://totp/a?secret=MY&secret=MY", "otpauth://totp/a?secret=MY&period=0",
            "otpauth://totp/a?secret=MY&digits=7", "otpauth://totp/a?secret=MY&algorithm=MD5",
            "otpauth-migration://offline?data=notbase64"
        ] { XCTAssertThrowsError(try OTPImport.parse(text), text) }
    }
    func testTruncatedGooglePayloadIsRejected() {
        let data = Data(base64Encoded: migrationFixture)!
        // The first 46 bytes contain the required complete entry; earlier truncation must fail.
        for count in 0..<46 {
            let text = "otpauth-migration://offline?data=" + data.prefix(count).base64EncodedString()
            XCTAssertThrowsError(try OTPImport.parse(text), "Accepted truncated prefix of length \(count)")
        }
    }
    func testGoogleHOTPAndUnknownAlgorithmRejected() {
        let original = Array(Data(base64Encoded: migrationFixture)!)
        for (offset, value) in [(45, UInt8(1)), (41, UInt8(4)), (43, UInt8(0))] {
            var data = original; data[offset] = value
            XCTAssertThrowsError(try OTPImport.parse("otpauth-migration://offline?data=" + Data(data).base64EncodedString()))
        }
    }
    func testPercentEncodedBase64AndLabels() throws {
        let escaped = migrationFixture.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        XCTAssertEqual(try OTPImport.parse("otpauth-migration://offline?data=" + escaped).accounts.count, 1)
        let result = try OTPImport.parse("otpauth://totp/My%20Service:alice%40example.com?secret=MY%3D%3D%3D%3D%3D%3D&issuer=My%20Service")
        XCTAssertEqual(result.accounts[0].name, "alice@example.com")
        XCTAssertEqual(result.accounts[0].secret, Data("f".utf8))
    }
}


extension ImportTests {
    func testUnbatchedGoogleExportAcceptsZeroBatchMetadata() throws {
        var data = Array(Data(base64Encoded: "CiwKFDEyMzQ1Njc4OTAxMjM0NTY3ODkwEgVhbGljZRoHRXhhbXBsZSABKAIwAhABGAIgASgH")!)
        data[49] = 0
        data[51] = 0
        let result = try OTPImport.parse("otpauth-migration://offline?data=" + Data(data).base64EncodedString())
        XCTAssertEqual(result.batchSize, 1)
        XCTAssertEqual(result.batchIndex, 0)
        XCTAssertEqual(result.accounts[0].code(at: Date(timeIntervalSince1970: 59)), "94287082")
    }
}


extension ImportTests {
    func testVersionTwoExportValidatesAccountFields() throws {
        var data = Array(Data(base64Encoded: "CiwKFDEyMzQ1Njc4OTAxMjM0NTY3ODkwEgVhbGljZRoHRXhhbXBsZSABKAIwAhABGAIgASgH")!)
        data[47] = 2
        let result = try OTPImport.parse("otpauth-migration://offline?data=" + Data(data).base64EncodedString())
        XCTAssertEqual(result.accounts.count, 1)
        XCTAssertEqual(result.accounts[0].code(at: Date(timeIntervalSince1970: 59)), "94287082")
        data[41] = 4
        XCTAssertThrowsError(try OTPImport.parse("otpauth-migration://offline?data=" + Data(data).base64EncodedString()))
    }
}
