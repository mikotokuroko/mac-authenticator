import CoreGraphics
import Vision

public enum QRImageReader {
    public static func payloads(in image: CGImage) throws -> [String] {
        guard image.width <= 12000, image.height <= 12000 else {
            throw OTPError.invalid("The QR image is too large. Try a smaller screenshot.")
        }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: image).perform([request])
        let payloads = (request.results ?? []).compactMap(\.payloadStringValue).filter {
            $0.hasPrefix("otpauth:") || $0.hasPrefix("otpauth-migration:")
        }
        guard !payloads.isEmpty else {
            throw OTPError.invalid("No authenticator QR code was found. Include the entire QR square in the image.")
        }
        return payloads
    }
}
