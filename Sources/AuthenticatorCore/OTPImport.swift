import Foundation

public struct OTPImportResult: Sendable {
    public var accounts: [OTPAccount]
    public var batchIndex: Int = 0
    public var batchSize: Int = 1
}
public enum OTPImport {
    public static func parse(_ text: String) throws -> OTPImportResult {
        guard text.utf8.count <= 1_000_000,
              let url = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw OTPError.invalid("This is not an authenticator QR code.")
        }
        var parameters: [String: String] = [:]
        for item in url.queryItems ?? [] {
            guard parameters[item.name] == nil else { throw OTPError.invalid("The QR code contains duplicate parameters.") }
            parameters[item.name] = item.value ?? ""
        }
        if url.scheme == "otpauth-migration", url.host == "offline" {
            guard let encoded = parameters["data"], let data = Data(base64Encoded: encoded) else {
                throw OTPError.invalid("The Google export QR code is incomplete.")
            }
            return try migration(data)
        }
        guard url.scheme == "otpauth", url.host == "totp" else {
            throw OTPError.invalid("Import a time-based authenticator QR code. Counter-based HOTP accounts are not supported.")
        }
        guard let secretText = parameters["secret"] else { throw OTPError.invalid("The QR code has no secret.") }
        let secret = try base32(secretText)
        let label = String(url.path.dropFirst())
        let parts = label.split(separator: ":", maxSplits: 1).map(String.init)
        let name = parts.last ?? ""
        let issuer = parameters["issuer"] ?? (parts.count == 2 ? parts[0] : "")
        guard let algorithm = OTPAlgorithm(rawValue: (parameters["algorithm"] ?? "SHA1").uppercased()),
              let digits = Int(parameters["digits"] ?? "6"), let period = Int(parameters["period"] ?? "30") else {
            throw OTPError.invalid("The QR code uses unsupported code settings.")
        }
        return OTPImportResult(accounts: [try OTPAccount(name: name, issuer: issuer, secret: secret, algorithm: algorithm, digits: digits, period: period)])
    }

    static func base32(_ string: String) throws -> Data {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
        let input = Array(string.uppercased().utf8)
        let body = Array(input.prefix { $0 != 61 })
        let padding = input.count - body.count
        guard input.dropFirst(body.count).allSatisfy({ $0 == 61 }),
              [0, 2, 4, 5, 7].contains(body.count % 8),
              padding == 0 || (input.count % 8 == 0 && padding < 7) else {
            throw OTPError.invalid("The account secret is not valid Base32.")
        }
        var result = Data(), accumulator = 0, bits = 0
        for character in body {
            guard let value = alphabet.firstIndex(of: character) else { throw OTPError.invalid("The account secret is not valid Base32.") }
            accumulator = (accumulator << 5) | value; bits += 5
            if bits >= 8 { bits -= 8; result.append(UInt8((accumulator >> bits) & 255)); accumulator &= (1 << bits) - 1 }
        }
        guard accumulator == 0, !result.isEmpty else { throw OTPError.invalid("The account secret is incomplete.") }
        return result
    }

    private static func migration(_ data: Data) throws -> OTPImportResult {
        let fields = try ProtoReader.read(data)
        let version = try fields.number(2, fallback: 1)
        let rawSize = try fields.number(3, fallback: 0)
        let size = max(1, rawSize)
        let index = try fields.number(4, fallback: 0)
        guard version <= 2 else { throw OTPError.invalid("Google export version \(version) is not supported yet.") }
        guard size <= 1000, index < size else { throw OTPError.invalid("The export has invalid batch metadata (size \(rawSize), index \(index)).") }
        let accounts = try fields.filter { $0.number == 1 }.map { field -> OTPAccount in
            guard let bytes = field.bytes else { throw OTPError.invalid("The Google export is malformed.") }
            let entry = try ProtoReader.read(bytes)
            guard try entry.number(6, fallback: 0) == 2 else { throw OTPError.invalid("This export contains a counter-based or unspecified account. Export only time-based accounts.") }
            let algorithm: OTPAlgorithm
            switch try entry.number(4, fallback: 0) {
            case 1: algorithm = .sha1
            case 2: algorithm = .sha256
            case 3: algorithm = .sha512
            default: throw OTPError.invalid("This export contains an unsupported algorithm.")
            }
            let digits: Int
            switch try entry.number(5, fallback: 0) {
            case 1: digits = 6
            case 2: digits = 8
            default: throw OTPError.invalid("This export contains an unsupported code length.")
            }
            let name = try entry.string(2), issuer = try entry.string(3)
            let cleanName = !issuer.isEmpty && name.hasPrefix(issuer + ":") ? String(name.dropFirst(issuer.count + 1)) : name
            return try OTPAccount(name: cleanName, issuer: issuer, secret: try entry.data(1), algorithm: algorithm, digits: digits)
        }
        guard !accounts.isEmpty else { throw OTPError.invalid("There are no accounts in this QR code.") }
        return OTPImportResult(accounts: accounts, batchIndex: Int(index), batchSize: Int(size))
    }
}

private struct ProtoField {
    let number: UInt64
    var value: UInt64? = nil
    var bytes: Data? = nil
}
private extension Array where Element == ProtoField {
    func single(_ number: UInt64) throws -> ProtoField? {
        let found = filter { $0.number == number }
        guard found.count <= 1 else { throw OTPError.invalid("The Google export has duplicate fields.") }
        return found.first
    }
    func number(_ number: UInt64, fallback: UInt64) throws -> UInt64 {
        guard let field = try single(number) else { return fallback }
        guard let value = field.value else { throw OTPError.invalid("The Google export has an invalid field.") }
        return value
    }
    func data(_ number: UInt64) throws -> Data {
        guard let field = try single(number) else { return Data() }
        guard let bytes = field.bytes else { throw OTPError.invalid("The Google export has an invalid field.") }
        return bytes
    }
    func string(_ number: UInt64) throws -> String {
        guard let text = String(data: try data(number), encoding: .utf8) else { throw OTPError.invalid("The account label is unreadable.") }
        return text
    }
}
private enum ProtoReader {
    static func read(_ data: Data) throws -> [ProtoField] {
        let bytes = Array(data)
        var position = 0, fields: [ProtoField] = []
        func varint() throws -> UInt64 {
            var result: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard position < bytes.count else { throw OTPError.invalid("The export QR code is truncated.") }
                let byte = bytes[position]; position += 1
                guard shift < 63 || byte <= 1 else { throw OTPError.invalid("The export QR code is malformed.") }
                result |= UInt64(byte & 127) << shift
                if byte & 128 == 0 { return result }
            }
            throw OTPError.invalid("The export QR code is malformed.")
        }
        while position < bytes.count {
            let tag = try varint(), number = tag >> 3, wire = tag & 7
            guard number > 0 else { throw OTPError.invalid("The export QR code is malformed.") }
            if wire == 0 { fields.append(ProtoField(number: number, value: try varint())) }
            else if wire == 2 {
                let length = try varint()
                guard length <= UInt64(bytes.count - position) else { throw OTPError.invalid("The export QR code is truncated.") }
                fields.append(ProtoField(number: number, bytes: Data(bytes[position..<position + Int(length)])))
                position += Int(length)
            } else if wire == 1 || wire == 5 {
                let length = wire == 1 ? 8 : 4
                guard length <= bytes.count - position else { throw OTPError.invalid("The export QR code is truncated.") }
                position += length
            } else { throw OTPError.invalid("The export QR code has an unsupported field.") }
        }
        return fields
    }
}
