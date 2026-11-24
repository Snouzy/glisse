import CoreGraphics

/// L'appareil posé à côté du Mac (iPhone ou iPad), et la taille de son écran en unités de souris.
/// iOS ne dit jamais où est son pointeur : on l'estime sur ce rectangle. Les valeurs sont des points de
/// départ à la vitesse de pointeur minimale, à ajuster avec les curseurs des réglages.
public enum Device: String, Sendable, Codable, CaseIterable {
    case iPhone
    case iPad

    public var name: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        }
    }

    /// Ce que le curseur parcourt d'un bord à l'autre, en unités de souris.
    public var screenSize: CGSize {
        switch self {
        case .iPhone: CGSize(width: 1200, height: 2600)
        case .iPad: CGSize(width: 1640, height: 2360)
        }
    }
}
