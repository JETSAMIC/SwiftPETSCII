import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// A single 40x25 screen snapshot plus a display duration. For static
/// PETSCII files (`.c`, `.pet`, `.seq` with no CHR$(147) frame breaks)
/// a document contains exactly one frame.
public struct PETSCIIFrame: Sendable, Equatable {
    /// The decoded screen state for this frame.
    public let screen: PETSCIIScreen
    /// How long this frame should be displayed in an animation playback,
    /// in seconds. Defaults to 100ms per the parser's `Options`.
    public let duration: TimeInterval

    public init(screen: PETSCIIScreen, duration: TimeInterval = 0.1) {
        self.screen = screen
        self.duration = duration
    }

    /// Render this frame to a native 320x200 CGImage.
    public var cgImage: CGImage? {
        PETSCIIRenderer.render(screen)
    }

    #if canImport(UIKit)
    /// UIImage wrapper for iOS / tvOS / visionOS.
    public var uiImage: UIImage? {
        guard let cg = cgImage else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif

    #if canImport(AppKit)
    /// NSImage wrapper for macOS.
    public var nsImage: NSImage? {
        guard let cg = cgImage else { return nil }
        return NSImage(
            cgImage: cg,
            size: NSSize(width: PETSCIIRenderer.pixelWidth,
                         height: PETSCIIRenderer.pixelHeight)
        )
    }
    #endif
}
