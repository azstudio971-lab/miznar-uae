import ReplayKit
import CoreImage
import UniformTypeIdentifiers

final class SampleHandler: RPBroadcastSampleHandler {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var lastFrame = Date.distantPast
    private var lastState = Date.distantPast
    private func state(_ active: Bool) {
        guard let url = CastShared.state else { return }
        try? JSONEncoder().encode(CastShared.RelayState(active: active, updated: Date())).write(to: url, options: [.atomic, .completeFileProtection])
    }
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) { state(true) }
    override func broadcastPaused() { state(false) }
    override func broadcastResumed() { state(true) }
    override func broadcastFinished() {
        state(false)
        if let frame = CastShared.frame { try? FileManager.default.removeItem(at: frame) }
    }
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, Date().timeIntervalSince(lastFrame) >= 1.0 / 12.0,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer), let destination = CastShared.frame else { return }
        lastFrame = Date()
        autoreleasepool {
            var image = CIImage(cvPixelBuffer: buffer)
            if let raw = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
                image = image.oriented(forExifOrientation: raw.int32Value)
            }
            let factor = min(1, 1280 / max(image.extent.width, image.extent.height))
            image = image.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
            if let data = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.65]) {
                try? data.write(to: destination, options: [.atomic, .completeFileProtection])
                if Date().timeIntervalSince(lastState) >= 1 { lastState = Date(); state(true) }
            }
        }
    }
}
