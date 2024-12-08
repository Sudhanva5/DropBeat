import Foundation
import Network
import CryptoKit

class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()
    private var server: NWListener?
    private var connections: [NWConnection] = []
    private let port: UInt16 = 8089
    private let queue = DispatchQueue(label: "com.sudhanva.dropbeat.websocket")
    
    @Published var isConnected = false
    @Published var currentTrack: Track?
    
    private init() {
        print("[DropBeat] WebSocket server initializing...")
        setupServer()
    }
    
    private func setupServer() {
        do {
            let parameters = NWParameters(tls: nil)
            parameters.allowLocalEndpointReuse = true
            
            let nwPort = NWEndpoint.Port(rawValue: port)!
            server = try NWListener(using: parameters, on: nwPort)
            
            server?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("[DropBeat] Server ready on port \(self?.port ?? 0)")
                    DispatchQueue.main.async {
                        self?.isConnected = true
                    }
                case .failed(let error):
                    print("[DropBeat] Server failed:", error)
                    DispatchQueue.main.async {
                        self?.isConnected = false
                    }
                    self?.restartServer()
                default:
                    break
                }
            }
            
            server?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            server?.start(queue: queue)
            
        } catch {
            print("[DropBeat] Failed to create server:", error)
            restartServer()
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        print("[DropBeat] New connection received")
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[DropBeat] Connection ready")
                self?.setupReceive(for: connection)
                self?.connections.append(connection)
                DispatchQueue.main.async {
                    self?.isConnected = true
                }
                
            case .failed(let error):
                print("[DropBeat] Connection failed:", error)
                self?.removeConnection(connection)
                
            case .cancelled:
                print("[DropBeat] Connection cancelled")
                self?.removeConnection(connection)
                
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func setupReceive(for connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("[DropBeat] Receive error:", error)
                self?.removeConnection(connection)
                return
            }
            
            if let data = data {
                self?.handleMessage(data)
            }
            
            if !isComplete {
                self?.setupReceive(for: connection)
            }
        }
    }
    
    private func handleMessage(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8),
              let json = try? JSONSerialization.jsonObject(with: Data(string.utf8), options: []) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "TRACK_INFO":
            if let trackData = json["data"] as? [String: Any] {
                let track = Track(
                    id: "\(trackData["title"] as? String ?? "")-\(trackData["artist"] as? String ?? "")")
                    title: trackData["title"] as? String ?? "No Track Playing",
                    artist: trackData["artist"] as? String ?? "Unknown Artist",
                    albumArt: trackData["albumArt"] as? String,
                    isLiked: trackData["isLiked"] as? Bool ?? false,
                    duration: trackData["duration"] as? Double ?? 0
                )
                
                DispatchQueue.main.async { [weak self] in
                    self?.currentTrack = track
                }
            }
        default:
            print("[DropBeat] Unknown message type:", type)
        }
    }
    
    private func removeConnection(_ connection: NWConnection) {
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
        connection.cancel()
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = !(self?.connections.isEmpty ?? true)
        }
    }
    
    private func restartServer() {
        connections.forEach { $0.cancel() }
        connections.removeAll()
        server?.cancel()
        server = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            print("[DropBeat] Attempting to restart server...")
            self?.setupServer()
        }
    }
    
    // MARK: - Public Methods
    
    func play() {
        sendCommand("play")
    }
    
    func pause() {
        sendCommand("pause")
    }
    
    func next() {
        sendCommand("next")
    }
    
    func previous() {
        sendCommand("previous")
    }
    
    private func sendCommand(_ command: String) {
        let message = ["type": "COMMAND", "command": command]
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        
        connections.forEach { connection in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("[DropBeat] Send error:", error)
                }
            })
        }
    }
}