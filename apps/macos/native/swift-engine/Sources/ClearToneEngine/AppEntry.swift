import AppKit
import SwiftUI

// MARK: - Entry Point

@main
struct ClearToneApp: App {
    @NSApplicationDelegateAdaptor(ClearToneAppDelegate.self) private var appDelegate
    @StateObject private var model = ClearToneAppModel()

    var body: some Scene {
        Window("ClearTone", id: "main") {
            DashboardView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 620)
        }
        .defaultSize(width: 880, height: 720)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.isProcessing ? "waveform.circle.fill" : "waveform.circle")
                .symbolRenderingMode(.monochrome)
                .imageScale(.medium)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 18, height: 18)
                .accessibilityLabel(model.isProcessing ? "ClearTone processing" : "ClearTone idle")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class ClearToneAppDelegate: NSObject, NSApplicationDelegate {
    static var terminationHandler: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let trayOnly = UserDefaults.standard.bool(forKey: "trayOnlyMode")
        Self.applyPresentationMode(trayOnly: trayOnly)
        if trayOnly {
            // SwiftUI creates the Window scene just after launch. Hide it on
            // the next run-loop turn as well so tray-only mode has no flash or
            // leftover desktop window after relaunch.
            DispatchQueue.main.async {
                Self.closeDesktopWindows()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.terminationHandler?()
    }

    static func applyPresentationMode(trayOnly: Bool) {
        NSApp.setActivationPolicy(trayOnly ? .accessory : .regular)
        if trayOnly {
            closeDesktopWindows()
            NSApp.deactivate()
        }
    }

    static func closeDesktopWindows() {
        for window in NSApp.windows where isDesktopWindow(window) {
            // Closing releases the SwiftUI render surface and backing store.
            // The Window scene remains reopenable through openWindow(id:).
            window.close()
        }
    }

    private static func isDesktopWindow(_ window: NSWindow) -> Bool {
        // MenuBarExtra uses a transient NSPanel. Only hide normal titled app
        // windows so the menu-bar control remains available.
        !(window is NSPanel) && window.styleMask.contains(.titled)
    }
}
