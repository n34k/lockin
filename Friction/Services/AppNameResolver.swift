import SwiftUI
import Vision
import FamilyControls
import ManagedSettings

// ApplicationToken.localizedDisplayName is nil outside ShieldConfigurationExtension,
// and even there Apple may not populate it. The only reliable source of app names
// is Label(token) in SwiftUI. This helper renders the title-only label offscreen
// via ImageRenderer and runs Vision OCR to extract the string.
@MainActor
enum AppNameResolver {
    static func resolveName(for token: ApplicationToken) async -> String? {
        await renderAndOCR(Label(token).labelStyle(.titleOnly))
    }

    static func resolveName(for token: ActivityCategoryToken) async -> String? {
        await renderAndOCR(Label(token).labelStyle(.titleOnly))
    }

    private static func renderAndOCR<V: View>(_ view: V) async -> String? {
        let renderer = ImageRenderer(
            content: view.font(.system(size: 24)).padding(8)
        )
        renderer.scale = 3.0
        guard let cgImage = renderer.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let name = (req.results as? [VNRecognizedTextObservation])?
                    .first?.topCandidates(1).first?.string
                continuation.resume(returning: name)
            }
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }
}
