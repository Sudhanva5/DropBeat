import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var wsManager = WebSocketManager.shared
    private var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        setupPopover()
        
        // Observe WebSocket connection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionChange),
            name: NSNotification.Name("WebSocketConnectionChanged"),
            object: nil
        )
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "DropBeat")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        updateMenu()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    @objc func handleConnectionChange() {
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // Now Playing Section
        if let currentTrack = wsManager.currentTrack {
            let nowPlayingItem = NSMenuItem()
            nowPlayingItem.title = "Now Playing: \(currentTrack.title)"
            nowPlayingItem.isEnabled = false
            menu.addItem(nowPlayingItem)
            
            let artistItem = NSMenuItem()
            artistItem.title = "By \(currentTrack.artist)"
            artistItem.isEnabled = false
            menu.addItem(artistItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Playback Controls
        let playPauseItem = NSMenuItem(
            title: "Play/Pause",
            action: #selector(togglePlayPause),
            keyEquivalent: "p"
        )
        menu.addItem(playPauseItem)
        
        let previousItem = NSMenuItem(
            title: "Previous",
            action: #selector(previousTrack),
            keyEquivalent: "["
        )
        menu.addItem(previousItem)
        
        let nextItem = NSMenuItem(
            title: "Next",
            action: #selector(nextTrack),
            keyEquivalent: "]"
        )
        menu.addItem(nextItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Like Button
        let likeItem = NSMenuItem(
            title: "Like",
            action: #selector(toggleLike),
            keyEquivalent: "l"
        )
        menu.addItem(likeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Connection Status
        let statusItem = NSMenuItem()
        statusItem.title = wsManager.isConnected ? "Connected" : "Disconnected"
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit DropBeat",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func togglePlayPause() {
        if let track = wsManager.currentTrack {
            if track.isPaused {
                wsManager.play()
            } else {
                wsManager.pause()
            }
        }
    }
    
    @objc func previousTrack() {
        wsManager.previous()
    }
    
    @objc func nextTrack() {
        wsManager.next()
    }
    
    @objc func toggleLike() {
        wsManager.toggleLike()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
} 