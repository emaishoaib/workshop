import Cocoa

/// this is a lightweight CALayer which displays an image
/// it is an alternative to NSView-based image display, avoiding AppKit overhead (layout recursion, responder chain, drag-and-drop)
class LightImageLayer: CALayer {
    override init() {
        super.init()
        contentsGravity = .resize
        magnificationFilter = .trilinear
        minificationFilter = .trilinear
        minificationFilterBias = 0.0
        shouldRasterize = false
        delegate = NoAnimationDelegate.shared
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    func updateContents(_ caLayerContents: CALayerContents, _ size: NSSize) {
        switch caLayerContents {
        case .cgImage(let image?):
            contents = image
        case .pixelBuffer(let pixelBuffer?):
            contents = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        default: break
        }
        if frame.size != size {
            frame.size = size
        }
    }

    func releaseImage() {
        contents = nil
    }
}

/// Moved here from the now-deleted kit/LightImageView.swift (LightImageView itself was only used
/// by PermissionsWindow/PreviewPanel, both deleted — but this enum is still used by Window.swift
/// and WindowCaptureEvents.swift, so it needed a new home).
enum CALayerContents {
    case cgImage(CGImage?)
    case pixelBuffer(CVPixelBuffer?)

    func size() -> NSSize? {
        switch self {
        case .cgImage(let image):
            return image?.size()
        case .pixelBuffer(let pixelBuffer):
            return pixelBuffer?.size()
        }
    }
}
