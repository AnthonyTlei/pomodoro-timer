/// The timer's layout direction. Existing installs retain the horizontal pill.
public enum PillOrientation: String, CaseIterable, Sendable {
    case horizontal, vertical

    public var title: String { self == .horizontal ? "Horizontal" : "Vertical" }
    public var opposite: Self { self == .horizontal ? .vertical : .horizontal }
}
