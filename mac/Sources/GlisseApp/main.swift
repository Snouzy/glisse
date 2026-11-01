import AppKit

let app = NSApplication.shared

// `GlisseApp --screenshots <dossier>` : rend les captures du README hors écran et sort.
if let i = CommandLine.arguments.firstIndex(of: "--screenshots"), i + 1 < CommandLine.arguments.count {
    app.setActivationPolicy(.prohibited)
    do {
        try Screenshots.run(into: CommandLine.arguments[i + 1])
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Captures impossibles : \(error)\n".utf8))
        exit(1)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
