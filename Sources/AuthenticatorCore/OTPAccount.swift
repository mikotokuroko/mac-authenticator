import Foundation
import CryptoKit

public enum OTPError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
public enum OTPAlgorithm: String, Codable, Sendable { case sha1 = "SHA1", sha256 = "SHA256", sha512 = "SHA512" }

public struct OTPAccount: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let issuer: String
    public let secret: Data
    public let algorithm: OTPAlgorithm
    public let digits: Int
    public let period: Int

    public init(id: UUID = UUID(), name: String, issuer: String, secret: Data, algorithm: OTPAlgorithm = .sha1, digits: Int = 6, period: Int = 30) throws {
        guard !secret.isEmpty, secret.count <= 1024 else { throw OTPError.invalid("The account has an invalid secret.") }
        guard !name.isEmpty, name.count <= 1024, issuer.count <= 1024 else { throw OTPError.invalid("The account has an invalid name.") }
        guard [6, 8].contains(digits), (1...3600).contains(period) else { throw OTPError.invalid("This code length or refresh interval is not supported.") }
        self.id = id; self.name = name; self.issuer = issuer; self.secret = secret
        self.algorithm = algorithm; self.digits = digits; self.period = period
    }
    public func code(at date: Date = Date()) -> String {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, seconds >= 0, seconds < Double(UInt64.max) else { return "—" }
        var counter = UInt64(seconds / Double(period)).bigEndian
        let message = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: secret)
        let digest: [UInt8]
        switch algorithm {
        case .sha1: digest = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: digest = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: digest = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        let offset = Int(digest.last! & 15)
        let number = digest[offset..<offset + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } & 0x7fff_ffff
        let modulus: UInt32 = digits == 8 ? 100_000_000 : 1_000_000
        return String(format: "%0*u", digits, number % modulus)
    }
    public func remaining(at date: Date) -> Int { period - Int(date.timeIntervalSince1970) % period }
    public func isSameCredential(as other: OTPAccount) -> Bool {
        secret == other.secret && algorithm == other.algorithm && digits == other.digits && period == other.period && name == other.name && issuer == other.issuer
    }
}
