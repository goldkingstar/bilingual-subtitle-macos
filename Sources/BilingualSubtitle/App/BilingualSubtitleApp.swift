import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct BilingualSubtitleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = SubtitleCoordinator()

    var body: some Scene {
        WindowGroup("双语字幕镜") {
            ContentView(coordinator: coordinator)
        }
        .defaultSize(width: 610, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("字幕") {
                Button("框选字幕区域…") {
                    coordinator.selectRegion()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                if coordinator.isRunning {
                    Button("停止识别") {
                        coordinator.stop()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("开始识别") {
                        coordinator.start()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
    }
}
