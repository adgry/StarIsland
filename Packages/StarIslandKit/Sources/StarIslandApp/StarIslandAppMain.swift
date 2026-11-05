import AppKit

@main
enum StarIslandAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = MainActor.assumeIsolated {
            AppCoordinator.shared
        }
        app.delegate = delegate
        app.run()
    }
}
