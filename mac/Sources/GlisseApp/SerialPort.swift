import Foundation
import Darwin
import GlisseCore

/// Le port série USB du dongle : ouverture, lignes reçues, écriture, reconnexion quand il est débranché.
final class SerialPort {
    var onLine: ((String) -> Void)?
    var onStateChange: (() -> Void)?

    private(set) var path: String?
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?
    private var buffer = Data()
    private var retry: Timer?
    private let preferredPath: () -> String

    var isOpen: Bool { fd >= 0 }

    init(preferredPath: @escaping () -> String) {
        self.preferredPath = preferredPath
    }

    /// Cherche le dongle toutes les deux secondes tant qu'il n'est pas ouvert.
    func start() {
        tryOpen()
        retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, !self.isOpen else { return }
            self.tryOpen()
        }
    }

    func stop() {
        retry?.invalidate()
        close()
    }

    /// Les ports USB série plausibles, le dongle d'abord.
    static func candidates() -> [String] {
        let all = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        let usb = all.filter { $0.hasPrefix("cu.") }
            .filter { name in
                ["usbserial", "SLAB_USBtoUART", "usbmodem", "wchusbserial"].contains { name.localizedCaseInsensitiveContains($0) }
            }
            .map { "/dev/" + $0 }
        return usb.sorted()
    }

    private func tryOpen() {
        let preferred = preferredPath()
        let paths = preferred.isEmpty ? Self.candidates() : [preferred]
        for p in paths where open(path: p) { return }
    }

    private func open(path: String) -> Bool {
        let handle = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard handle >= 0 else { return false }
        var tty = termios()
        guard tcgetattr(handle, &tty) == 0 else { Darwin.close(handle); return false }
        cfmakeraw(&tty)
        cfsetspeed(&tty, speed_t(B115200))
        tty.c_cflag |= tcflag_t(CLOCAL | CREAD)
        tty.c_cflag &= ~tcflag_t(CRTSCTS)
        guard tcsetattr(handle, TCSANOW, &tty) == 0 else { Darwin.close(handle); return false }
        // Les cartes ESP32 redémarrent quand DTR bascule à l'ouverture : laisser le temps au dongle.
        fd = handle
        self.path = path
        buffer.removeAll()
        let src = DispatchSource.makeReadSource(fileDescriptor: handle, queue: .main)
        src.setEventHandler { [weak self] in self?.readAvailable() }
        src.setCancelHandler { Darwin.close(handle) }
        src.resume()
        source = src
        onStateChange?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.write(Wire.status) }
        return true
    }

    private func close() {
        guard fd >= 0 else { return }
        source?.cancel()
        source = nil
        fd = -1
        path = nil
        onStateChange?()
    }

    private func readAvailable() {
        var chunk = [UInt8](repeating: 0, count: 512)
        let n = Darwin.read(fd, &chunk, chunk.count)
        if n <= 0 {
            if n == 0 || (errno != EAGAIN && errno != EINTR) { close() }
            return
        }
        buffer.append(contentsOf: chunk[0..<n])
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                onLine?(line)
            }
        }
    }

    private let writer = DispatchQueue(label: "io.snouzy.glisse.serial", qos: .userInteractive)

    /// Écrit en dehors du fil appelant : le tap d'événements doit répondre vite, sinon macOS le désactive.
    func write(_ text: String) {
        let handle = fd
        guard handle >= 0 else { return }
        let bytes = Array(text.utf8)
        writer.async { [weak self] in
            var offset = 0
            while offset < bytes.count {
                let n = bytes[offset...].withUnsafeBufferPointer { Darwin.write(handle, $0.baseAddress, $0.count) }
                if n < 0 {
                    if errno == EAGAIN { usleep(500); continue }
                    DispatchQueue.main.async { self?.close() }
                    return
                }
                offset += n
            }
        }
    }
}
