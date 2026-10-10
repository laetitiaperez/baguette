/// Masque : un `UInt8` par pixel, 0 = non sélectionné, 255 = sélectionné.
public struct Mask: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var values: [UInt8]

    public init(width: Int, height: Int, value: UInt8 = 0) {
        self.width = width
        self.height = height
        self.values = [UInt8](repeating: value, count: width * height)
    }

    public init(width: Int, height: Int, values: [UInt8]) {
        precondition(values.count == width * height, "Mask: values.count doit valoir width * height")
        self.width = width
        self.height = height
        self.values = values
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        get { values[y * width + x] }
        set { values[y * width + x] = newValue }
    }

    /// Vrai si tout le masque vaut 0.
    public var isEmpty: Bool { !values.contains { $0 != 0 } }
}
