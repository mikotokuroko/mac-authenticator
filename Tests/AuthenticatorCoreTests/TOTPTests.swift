import XCTest
@testable import AuthenticatorCore
final class TOTPTests: XCTestCase {
    func testRFC6238SHA1VectorAndThirtySecondBoundary() throws {
        let account = try OTPAccount(name: "RFC test", issuer: "", secret: Data("12345678901234567890".utf8), algorithm: .sha1, digits: 8)
        XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: 59)), "94287082")
        XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: 30)), "94287082")
        XCTAssertNotEqual(account.code(at: Date(timeIntervalSince1970: 60)), "94287082")
    }
}

extension TOTPTests {
    func testAllRFC6238Vectors() throws {
        let times: [TimeInterval] = [59, 1111111109, 1111111111, 1234567890, 2000000000, 20000000000]
        let cases: [(OTPAlgorithm, String, [String])] = [
            (.sha1, "12345678901234567890", ["94287082", "07081804", "14050471", "89005924", "69279037", "65353130"]),
            (.sha256, "12345678901234567890123456789012", ["46119246", "68084774", "67062674", "91819424", "90698825", "77737706"]),
            (.sha512, "1234567890123456789012345678901234567890123456789012345678901234", ["90693936", "25091201", "99943326", "93441116", "38618901", "47863826"])
        ]
        for (algorithm, secret, expected) in cases {
            let account = try OTPAccount(name: "RFC", issuer: "Test", secret: Data(secret.utf8), algorithm: algorithm, digits: 8)
            for (time, code) in zip(times, expected) { XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: time)), code) }
        }
    }
    func testCountdownAndSixDigitCode() throws {
        let account = try OTPAccount(name: "Test", issuer: "", secret: Data("12345678901234567890".utf8))
        XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: 59)), "287082")
        XCTAssertEqual(account.remaining(at: Date(timeIntervalSince1970: 59)), 1)
        XCTAssertEqual(account.remaining(at: Date(timeIntervalSince1970: 60)), 30)
    }
}
