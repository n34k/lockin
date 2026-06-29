import SwiftUI
import Vision
import FamilyControls
import ManagedSettings
import os

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

    // Rendering touches SwiftUI/ImageRenderer and must stay on the main actor;
    // the Vision OCR is CPU-bound and runs off-main so it never stalls the UI.
    private static func renderAndOCR<V: View>(_ view: V) async -> String? {
        let renderer = ImageRenderer(
            content: view.font(.system(size: 24)).padding(8)
        )
        renderer.scale = 3.0
        guard let cgImage = renderer.cgImage else { return nil }
        return await Self.recognizeText(in: cgImage)
    }

    private nonisolated static func recognizeText(in cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            // Guard against double-resume: the request handler fires the completion,
            // but if `perform` throws the handler never runs — resume nil in that case.
            let didResume = OSAllocatedUnfairLock(initialState: false)
            func finish(_ name: String?) {
                let shouldResume = didResume.withLock { resumed -> Bool in
                    guard !resumed else { return false }
                    resumed = true
                    return true
                }
                if shouldResume { continuation.resume(returning: name) }
            }

            let request = VNRecognizeTextRequest { req, _ in
                let name = (req.results as? [VNRecognizedTextObservation])?
                    .first?.topCandidates(1).first?.string
                finish(name)
            }
            request.recognitionLevel = .accurate
            do {
                try VNImageRequestHandler(cgImage: cgImage).perform([request])
            } catch {
                finish(nil)
            }
        }
    }
}
