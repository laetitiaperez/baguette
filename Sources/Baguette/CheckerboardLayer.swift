import QuartzCore

/// Damier dessiné sous l'image (visible là où elle est transparente). Le calque ne couvre que la partie
/// visible de l'image : sa taille reste celle de l'écran quel que soit le zoom. Les cases restent
/// alignées sur le coin de l'image grâce à `phase`.
final class CheckerboardLayer: CALayer {
    static let side: CGFloat = 8

    var lightColor: CGColor? { didSet { setNeedsDisplay() } }
    var darkColor: CGColor? { didSet { setNeedsDisplay() } }
    /// Position du coin haut-gauche de l'image dans le repère du calque.
    var phase: CGPoint = .zero { didSet { setNeedsDisplay() } }

    override init() {
        super.init()
        needsDisplayOnBoundsChange = true
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? CheckerboardLayer {
            lightColor = other.lightColor
            darkColor = other.darkColor
            phase = other.phase
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non pris en charge") }

    override func draw(in ctx: CGContext) {
        guard let lightColor, let darkColor else { return }
        let side = Self.side
        ctx.setFillColor(lightColor)
        ctx.fill(bounds)
        ctx.setFillColor(darkColor)
        // Cases de la première rangée/colonne visibles, comptées depuis le coin de l'image.
        let firstColumn = Int(floor((bounds.minX - phase.x) / side))
        let firstRow = Int(floor((bounds.minY - phase.y) / side))
        let columns = Int(ceil(bounds.width / side)) + 2
        let rows = Int(ceil(bounds.height / side)) + 2
        for row in firstRow..<(firstRow + rows) {
            for column in firstColumn..<(firstColumn + columns) where (row + column) & 1 == 1 {
                ctx.fill(CGRect(x: phase.x + CGFloat(column) * side, y: phase.y + CGFloat(row) * side,
                                width: side, height: side))
            }
        }
    }
}
