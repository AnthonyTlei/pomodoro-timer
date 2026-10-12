import CoreGraphics
import PomodoroCore

/// One geometry contract for drawing, native hit testing, previews and placement.
/// The long axis transposes; artwork, text and button glyphs stay upright.
public struct PillLayout: Equatable, Sendable {
    public let orientation: PillOrientation
    public init(orientation: PillOrientation = .horizontal) { self.orientation = orientation }
    public static let margin: CGFloat = 110
    public enum Metrics {
        public static let height: CGFloat = 46

        public static let leading: CGFloat = 11
        public static let trailing: CGFloat = 10

        public static let ring: CGFloat = 28
        public static let ringGap: CGFloat = 9
        public static let readout: CGFloat = 74
        public static let readoutGap: CGFloat = 12

        /// The play/pause button, larger than the rest because it is the one control
        /// that is always there.
        public static let primary: CGFloat = 28
        public static let secondary: CGFloat = 26
        public static let controlGap: CGFloat = 6

        /// The play button's leading edge, measured from the pill's own.
        public static let primaryX = leading + ring + ringGap + readout + readoutGap

        /// The leading edge of the nth secondary control, counting outward from the
        /// play button.
        public static func secondaryX(_ index: Int) -> CGFloat {
            primaryX + primary + controlGap + CGFloat(index) * (secondary + controlGap)
        }

        /// How far back the nth secondary control sits when parked, so its leading
        /// edge lands on the play button's.
        public static func tuck(_ index: Int) -> CGFloat { primaryX - secondaryX(index) }

        /// Two secondary controls and the trailing inset past them.
        public static let width = secondaryX(1) + secondary + trailing

        /// The collapsed form ends one trailing inset past the play button, which
        /// leaves it with exactly the air it has in the open pill — so the short bar
        /// is a real end to the layout rather than a crop through it.
        public static let compactWidth = primaryX + primary + trailing
    }

    public var size: CGSize { size(length: Metrics.width) }
    public var compactSize: CGSize { size(length: Metrics.compactWidth) }
    public var panelSize: CGSize {
        CGSize(width: size.width + Self.margin * 2, height: size.height + Self.margin * 2)
    }
    public var pillFrame: CGRect { CGRect(x: Self.margin, y: Self.margin, width: size.width, height: size.height) }
    public var compactFrame: CGRect { CGRect(origin: pillFrame.origin, size: compactSize) }
    public var dragFrame: CGRect { CGRect(origin: pillFrame.origin, size: size(length: Metrics.primaryX)) }
    public func visibleFrame(compact: Bool) -> CGRect { compact ? compactFrame : pillFrame }
    public func size(length: CGFloat) -> CGSize {
        orientation == .horizontal ? CGSize(width: length, height: Metrics.height)
            : CGSize(width: Metrics.height, height: length)
    }
    /// Native windows use bottom-left coordinates; SwiftUI and companion docks use top-left.
    public func nativeRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: panelSize.height - rect.maxY, width: rect.width, height: rect.height)
    }
    public func controlFrame(index: Int) -> CGRect {
        let length = index == 0 ? Metrics.primary : Metrics.secondary
        let offset = index == 0 ? Metrics.primaryX : Metrics.secondaryX(index - 1)
        return orientation == .horizontal
            ? CGRect(x: pillFrame.minX + offset, y: pillFrame.midY - length / 2, width: length, height: length)
            : CGRect(x: pillFrame.midX - length / 2, y: pillFrame.minY + offset, width: length, height: length)
    }
}
