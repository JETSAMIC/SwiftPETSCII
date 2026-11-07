import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// A single 40×25 screen snapshot plus a display duration.
///
/// A stream without `CLR` (`0x93`) frame breaks yields exactly one frame.
public struct PETSCIIFrame: Sendable, Equatable {
    /// The decoded screen state for this frame.
    public let screen: PETSCIIScreen
    /// How long this frame should be displayed in an animation playback,
    /// in seconds (``PETSCIIParser/Options/defaultFrameDuration``).
    public let duration: TimeInterval

    /// Creates a frame.
    ///
    /// - Parameters:
    ///   - screen: The screen contents.
    ///   - duration: Display duration in seconds.
    public init(screen: PETSCIIScreen, duration: TimeInterval = 0.1) {
        self.screen = screen
        self.duration = duration
    }

    /// This frame rendered to a native 320×200 `CGImage` with the default
    /// palette and the screen's character set.
    public var cgImage: CGImage? {
        PETSCIIRenderer.render(screen)
    }

    /// Renders this frame to a native 320×200 `CGImage`.
    ///
    /// - Parameters:
    ///   - palette: RGB palette for the 16 colors.
    ///   - charsetMode: How each cell's character set is chosen.
    /// - Returns: The image, or `nil` if CoreGraphics cannot create it.
    public func cgImage(
        palette: C64Palette,
        charsetMode: PETSCIIRenderer.CharsetMode = .screen
    ) -> CGImage? {
        PETSCIIRenderer.render(screen, palette: palette, charsetMode: charsetMode)
    }

    #if canImport(UIKit)
    /// This frame as a `UIImage` (iOS, iPadOS, tvOS, visionOS, watchOS).
    public var uiImage: UIImage? {
        guard let cg = cgImage else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif

    #if canImport(AppKit)
    /// This frame as an `NSImage` (macOS).
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
