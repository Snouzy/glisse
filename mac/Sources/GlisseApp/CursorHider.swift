import CoreGraphics
import Darwin

/// Masque la flèche du Mac pendant que la souris est sur l'iPhone. Une app en arrière-plan n'a pas le droit
/// de cacher le curseur : la propriété de connexion « SetsCursorInBackground » du serveur de fenêtres le lui
/// donne (API privée de SkyLight, celle qu'utilisent Synergy et Barrier). Si elle manque, la flèche reste.
enum CursorHider {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
    private static var hidden = false

    static func allowHidingInBackground() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
              let main = dlsym(handle, "CGSMainConnectionID"),
              let set = dlsym(handle, "CGSSetConnectionProperty") else { return }
        let cid = unsafeBitCast(main, to: MainConnection.self)()
        _ = unsafeBitCast(set, to: SetProperty.self)(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }

    static func hide() {
        guard !hidden else { return }
        hidden = true
        CGDisplayHideCursor(CGMainDisplayID())
    }

    static func show() {
        guard hidden else { return }
        hidden = false
        CGDisplayShowCursor(CGMainDisplayID())
    }
}
