import Cocoa

/// thin NSView wrapper around LightImageLayer, for use where AppKit requires an NSView (contentView, Auto Layout, NSStackView)
class LightImageView: NSView {
    let imageLayer: LightImageLayer

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override init(frame frameRect: NSRect = .zero) {
        imageLayer = LightImageLayer()
        super.init(frame: frameRect)
        wantsLayer = true
        layer!.addSublayer(imageLayer)
        layerContentsRedrawPolicy = .never
    }

    override func layout() {
        super.layout()
        imageLayer.frame = bounds
    }

    func updateContents(_ caLayerContents: CALayerContents, _ size: NSSize) {
        imageLayer.updateContents(caLayerContents, size)
        if frame.size != size {
            frame.size = size
        }
    }

    func releaseImage() {
        imageLayer.releaseImage()
    }
}

// Note: `CALayerContents` (used above) now lives in kit/LightImageLayer.swift, not here — it
// moved there when this file was briefly deleted and needed a new home for its still-live
// consumers (Window.swift, WindowCaptureEvents.swift). Restoring this file's `LightImageView`
// class (used by PermissionsWindow) reuses that same enum rather than re-declaring it.
