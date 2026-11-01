import CoreGraphics

/// La courbe entre le déplacement reçu du Mac et celui envoyé à l'iPhone.
///
/// macOS a déjà accéléré ses deltas et iOS accélère encore par-dessus : un geste rapide file, un geste lent
/// rampe. `linearity` à 1 laisse tout proportionnel (`gain` × delta). En dessous, la norme du déplacement
/// est élevée à cette puissance autour d'une référence de 10 points par événement : les petits gestes
/// gagnent, les grands sont retenus, la direction ne change pas.
public struct Response: Sendable {
    public var gain: Double
    public var linearity: Double
    /// Le déplacement par événement qui passe inchangé (hors gain), en points.
    public static let reference: Double = 10

    public init(gain: Double, linearity: Double) {
        self.gain = gain
        self.linearity = min(max(linearity, 0.1), 1)
    }

    public func apply(dx: Double, dy: Double) -> CGVector {
        let norm = (dx * dx + dy * dy).squareRoot()
        guard norm > 0 else { return .zero }
        let shaped: Double
        if linearity >= 0.999 {
            shaped = norm
        } else {
            let ref = Self.reference
            shaped = ref * pow(norm / ref, linearity)
        }
        let k = gain * shaped / norm
        return CGVector(dx: dx * k, dy: dy * k)
    }
}
