import CoreGraphics

/// Le bord de l'écran du Mac par lequel on passe sur l'iPhone.
public enum Edge: String, Sendable, Codable, CaseIterable {
    case left, right
}

/// Décide quand le curseur quitte le Mac : il doit être collé au bord et la souris continuer à pousser
/// dehors sur `resistance` points cumulés. Pousser dans l'autre sens, ou s'écarter du bord, remet le compte
/// à zéro. La résistance évite de partir sur l'iPhone en visant un bouton au bord de l'écran.
public struct EdgeGuard: Sendable {
    public var edge: Edge
    public var resistance: Double
    private var pushed: Double = 0

    public init(edge: Edge, resistance: Double) {
        self.edge = edge
        self.resistance = resistance
    }

    /// `at` est la position du curseur dans `screen`, `dx` le déplacement horizontal que la souris vient de faire.
    /// Renvoie true quand il faut passer sur l'iPhone.
    public mutating func push(at point: CGPoint, dx: Double, in screen: CGRect) -> Bool {
        let atEdge: Bool
        let outward: Double
        switch edge {
        case .right:
            atEdge = point.x >= screen.maxX - 1
            outward = dx
        case .left:
            atEdge = point.x <= screen.minX
            outward = -dx
        }
        guard atEdge, outward > 0 else {
            pushed = 0
            return false
        }
        pushed += outward
        if pushed >= resistance {
            pushed = 0
            return true
        }
        return false
    }

    public mutating func reset() { pushed = 0 }
}
