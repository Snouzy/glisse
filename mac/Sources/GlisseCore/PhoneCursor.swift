import CoreGraphics

/// Ce qu'un mouvement de souris produit quand le curseur est sur l'iPhone.
public enum PhoneMove: Equatable, Sendable {
    /// Envoyer ce déplacement au dongle, en unités entières de souris.
    case moved(dx: Int, dy: Int)
    /// Le curseur estimé est ressorti du côté du Mac, à cette hauteur (0 en haut, 1 en bas).
    case returnedToMac(yFraction: Double)
}

/// Le curseur tel que le Mac l'imagine sur l'iPhone. iOS ne dit jamais où est son pointeur : on intègre les
/// déplacements envoyés sur un rectangle de la taille de l'iPhone, en unités de souris. Quand l'estimation
/// pousse contre le côté du Mac sur `returnResistance` unités, le Mac reprend la main. Les autres côtés
/// retiennent le curseur, comme iOS le fait.
///
/// Les déplacements partent au dongle même quand l'estimation est bloquée à un bord : iOS retient son
/// pointeur au même bord, donc le vrai curseur vient se recaler sur l'estimation à chaque bord touché.
public struct PhoneCursor: Sendable {
    /// Le côté de l'iPhone qui touche le Mac : `.left` quand l'iPhone est à droite du Mac.
    public var macSide: Edge
    public var size: CGSize
    /// Unités envoyées au dongle par point de déplacement sur le Mac.
    public var gain: Double
    /// Unités de poussée contre le côté du Mac avant de revenir. Absorbe l'écart entre l'estimation et le
    /// vrai pointeur, qu'iOS accélère.
    public var returnResistance: Double
    public private(set) var position: CGPoint = .zero
    private var carry = CGVector(dx: 0, dy: 0)
    private var pushedOut: Double = 0

    public init(size: CGSize, macSide: Edge, gain: Double, returnResistance: Double) {
        self.size = size
        self.macSide = macSide
        self.gain = gain
        self.returnResistance = returnResistance
    }

    private var macEdgeX: Double { macSide == .left ? 0 : size.width - 1 }

    /// Le curseur arrive du Mac, à cette hauteur relative.
    public mutating func enter(yFraction: Double) {
        let y = (min(max(yFraction, 0), 1) * size.height).rounded(.down)
        position = CGPoint(x: macEdgeX, y: min(y, size.height - 1))
        carry = CGVector(dx: 0, dy: 0)
        pushedOut = 0
    }

    public mutating func move(dx: Double, dy: Double) -> PhoneMove {
        carry.dx += dx * gain
        carry.dy += dy * gain
        let ux = carry.dx.rounded(.towardZero)
        let uy = carry.dy.rounded(.towardZero)
        carry.dx -= ux
        carry.dy -= uy

        var next = CGPoint(x: position.x + ux, y: position.y + uy)
        next.y = min(max(next.y, 0), size.height - 1)
        let outward = macSide == .left ? -next.x : next.x - (size.width - 1)
        if outward > 0 {
            pushedOut += outward
            position = CGPoint(x: macEdgeX, y: next.y)
            if pushedOut >= returnResistance {
                pushedOut = 0
                return .returnedToMac(yFraction: next.y / size.height)
            }
            return .moved(dx: Int(ux), dy: Int(uy))
        }
        let inward = macSide == .left ? ux > 0 : ux < 0
        if inward { pushedOut = 0 }
        next.x = min(max(next.x, 0), size.width - 1)
        position = next
        return .moved(dx: Int(ux), dy: Int(uy))
    }
}
