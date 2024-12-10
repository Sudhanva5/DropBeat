import Foundation
import Network
import CryptoKit

private extension String {
    func sha1() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return Data(hash).base64EncodedString()
    }
}

class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()
    
    private var server: NWListener?
    private var activeConnection: NWConnection?
    private let port: UInt16 = 8089
    private let queue = DispatchQueue(label: "com.sudhanva.dropbeat.websocket")
    
    private var reconnectAttempts: Int = 0
    private var lastPongReceived: Date = Date()
    private let PING_INTERVAL: TimeInterval = 5.0
    
    @Published var isConnected = false
    @Published var currentTrack: Track?
    
    private init() {
        print("🎵 [DropBeat] Initializing WebSocket Manager...")
        setupServer()
        startPingInterval()
    }
    
    private func setupServer() {
        do {
            print("🎵 [DropBeat] Setting up WebSocket server on port \(port)...")
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            let nwPort = NWEndpoint.Port(rawValue: port)!
            server = try NWListener(using: parameters, on: nwPort)
            
            server?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("✅ [DropBeat] Server ready on port \(self?.port ?? 0)")
                    DispatchQueue.main.async {
                        self?.isConnected = true
                        self?.handleConnectionChange()
                    }
                case .failed(let error):
                    print("❌ [DropBeat] Server failed: \(error)")
                    self?.handleServerFailure()
                case .cancelled:
                    print("🔴 [DropBeat] Server cancelled")
                    self?.handleServerFailure()
                default:
                    print("ℹ️ [DropBeat] Server state: \(state)")
                }
            }
            
            server?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            print("🎵 [DropBeat] Starting server...")
            server?.start(queue: queue)
            
        } catch {
            print("❌ [DropBeat] Failed to create server: \(error)")
            handleServerFailure()
        }
    }
    
    private func startPingInterval() {
        queue.asyncAfter(deadline: .now() + PING_INTERVAL) { [weak self] in
            guard let self = self else { return }
            self.checkConnection()
            self.startPingInterval()
        }
    }
    
    private func checkConnection() {
        let timeSinceLastPong = Date().timeIntervalSince(lastPongReceived)
        if timeSinceLastPong > PING_INTERVAL * 2 {
            print("⚠️ [DropBeat] Connection seems dead, last pong was \(timeSinceLastPong) seconds ago")
            handleServerFailure()
        }
    }
    
    private func handleServerFailure() {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.handleConnectionChange()
        }
        activeConnection?.cancel()
        activeConnection = nil
        server?.cancel()
        server = nil
        
        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            print("🔄 [DropBeat] Attempting server restart...")
            self?.setupServer()
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        print("🔵 [DropBeat] New connection attempt")
        
        // If we have an active connection, close it
        if let existingConnection = activeConnection {
            print("⚠️ [DropBeat] Closing existing connection")
            existingConnection.cancel()
            activeConnection = nil
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .preparing:
                print("ℹ️ [DropBeat] Connection state: preparing")
            case .ready:
                print("✅ [DropBeat] Connection ready")
                self?.setupReceive(for: connection)
                self?.activeConnection = connection
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.handleConnectionChange()
                }
            case .failed(let error):
                print("❌ [DropBeat] Connection failed: \(error)")
                self?.handleConnectionFailure(connection)
            case .cancelled:
                print("🔴 [DropBeat] Connection cancelled")
                self?.handleConnectionFailure(connection)
            case .waiting(let error):
                print("⏳ [DropBeat] Connection waiting: \(error)")
            default:
                print("ℹ️ [DropBeat] Connection state: \(state)")
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func handleConnectionFailure(_ connection: NWConnection) {
        if connection === activeConnection {
            print("🔌 [DropBeat] Active connection lost")
            activeConnection = nil
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.handleConnectionChange()
            }
        }
        connection.cancel()
    }
    
    private func handleConnectionChange() {
        NotificationCenter.default.post(
            name: NSNotification.Name("WebSocketConnectionChanged"),
            object: nil,
            userInfo: ["isConnected": isConnected]
        )
    }
    
    private func setupReceive(for connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("❌ [DropBeat] Receive error:", error)
                self?.handleConnectionFailure(connection)
                return
            }
            
            if let data = data {
                print("📥 [DropBeat] Raw data received:", data.count, "bytes")
                print("📥 [DropBeat] Raw bytes:", data.map { String(format: "%02x", $0) }.joined(separator: " "))
                
                // Add this debug print
                print("🔍 About to decode WebSocket frame...")
                
                // If it's a GET request, handle it as a WebSocket upgrade
                if let str = String(data: data, encoding: .utf8), str.hasPrefix("GET") {
                    print("👋 Handling as WebSocket handshake")
                    self?.handleWebSocketHandshake(str, connection: connection)
                } else {
                    print("📦 Handling as WebSocket frame")
                    if let decodedData = self?.decodeWebSocketFrame(data) {
                        print("✅ Frame decoded successfully")
                        self?.handleMessage(decodedData)
                    } else {
                        print("❌ Frame decoding failed")
                    }
                }
            }
            
            if !isComplete {
                self?.setupReceive(for: connection)
            }
        }
    }
    
    private func handleWebSocketHandshake(_ request: String, connection: NWConnection) {
        print("🤝 [DropBeat] Processing handshake request:\n\(request)")
        
        // Split request into lines and extract headers
        let requestLines = request.components(separatedBy: "\r\n")
        var headers: [String: String] = [:]
        
        for line in requestLines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        
        // Check for required WebSocket headers
        guard let websocketKey = headers["Sec-WebSocket-Key"] else {
            print("❌ [DropBeat] Missing Sec-WebSocket-Key header")
            handleConnectionFailure(connection)
            return
        }
        
        // Generate WebSocket accept key
        let magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let acceptKey = (websocketKey + magicString).sha1()
        
        // Construct response with proper headers
        let response = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: \(acceptKey)",
            "",
            ""  // Empty line at the end is required
        ].joined(separator: "\r\n")
        
        print("🤝 [DropBeat] Sending handshake response:\n\(response)")
        
        // Send handshake response
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ [DropBeat] Handshake failed: \(error)")
                self?.handleConnectionFailure(connection)
            } else {
                print("✅ [DropBeat] Handshake successful")
                self?.lastPongReceived = Date()
            }
        })
    }
    
    private func handleMessage(_ data: Data) {
        if let str = String(data: data, encoding: .utf8) {
            print("📝 [DropBeat] Message:", str)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String {
                
                print("📦 [DropBeat] Message type:", type)
                
                switch type {
                case "PING":
                    print("🏓 [DropBeat] Got PING, sending PONG")
                    sendResponse(["type": "PONG", "timestamp": Date().timeIntervalSince1970])
                    lastPongReceived = Date()
                    
                case "TRACK_INFO":
                    if let trackData = json["data"] as? [String: Any],
                       let trackJson = try? JSONSerialization.data(withJSONObject: trackData),
                       let track = try? JSONDecoder().decode(Track.self, from: trackJson) {
                        DispatchQueue.main.async { [weak self] in
                            self?.currentTrack = track
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TrackChanged"),
                                object: nil,
                                userInfo: ["track": track]
                            )
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func decodeWebSocketFrame(_ data: Data) -> Data? {
        let headerSize = 2
        let maskSize = 4
        let payloadStart = headerSize + maskSize
        
        guard data.count >= (headerSize + maskSize) else {
            print("❌ Frame too small: \(data.count) bytes")
            return nil
        }
        
        // Get mask and payload
        let mask = Array(data[headerSize..<payloadStart])
        let payload = Array(data[payloadStart...])
        
        print("🔍 Frame Analysis:")
        print("  Header:", Array(data[0..<2]).map { String(format: "%02x", $0) }.joined(separator: " "))
        print("  Mask:", mask.map { String(format: "%02x", $0) }.joined(separator: " "))
        
        // Unmask data safely
        var unmasked = [UInt8]()
        for i in 0..<payload.count {
            let maskIndex = i % mask.count
            let unmaskedByte = payload[i] ^ mask[maskIndex]
            unmasked.append(unmaskedByte)
        }
        
        if let str = String(data: Data(unmasked), encoding: .utf8) {
            print("📄 Decoded text:", str)
        }
        
        return Data(unmasked)
    }
    
    private func createWebSocketFrame(withPayload payload: Data) -> Data {
        var frame = Data()
        
        // First byte: FIN bit and opcode for text frame
        frame.append(0x81)  // 1000 0001: FIN=1, Opcode=1 (text)
        
        // Second byte: Payload length and mask bit (no mask for server)
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count < 65536 {
            frame.append(126)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        } else {
            frame.append(127)
            for i in stride(from: 7, through: 0, by: -1) {
                frame.append(UInt8((payload.count >> (i * 8)) & 0xFF))
            }
        }
        
        // Add payload without masking
        frame.append(payload)
        return frame
    }
    
    private func sendResponse(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else {
            print("❌ [DropBeat] Failed to serialize response")
            return
        }
        
        let frame = createWebSocketFrame(withPayload: data)
        print("📤 [DropBeat] Sending response frame of size: \(frame.count) bytes")
        print("📤 [DropBeat] Response content: \(message)")
        
        activeConnection?.send(content: frame, completion: .contentProcessed { error in
            if let error = error {
                print("❌ [DropBeat] Failed to send response: \(error)")
            } else {
                print("✅ [DropBeat] Response sent successfully")
            }
        })
    }
    
    // MARK: - Public Methods
    
    func next() {
        print("⏭️ [DropBeat] Next track")
        sendCommand("next")
    }
    
    func previous() {
        print("⏮️ [DropBeat] Previous track")
        sendCommand("previous")
    }
    
    func play() {
        print("▶️ [DropBeat] Play")
        sendCommand("play")
    }
    
    func pause() {
        print("⏸️ [DropBeat] Pause")
        sendCommand("pause")
    }
    
    func toggleLike() {
        print("❤️ [DropBeat] Toggle like")
        sendCommand("toggleLike")
    }
    
    private func sendCommand(_ command: String) {
        let message = ["type": "COMMAND", "command": command]
        sendResponse(message)
    }
}
