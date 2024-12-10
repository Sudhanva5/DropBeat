import SwiftUI

struct ContentView: View {
    @ObservedObject var wsManager: WebSocketManager = .shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection Status (for debugging)
            HStack {
                Circle()
                    .fill(wsManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(wsManager.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(wsManager.isConnected ? .green : .red)
            }
            .padding(.top, 8)
            
            // Player Info
            HStack {
                // Album Art
                if let albumArt = wsManager.currentTrack?.albumArt,
                   let url = URL(string: albumArt) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(4)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(wsManager.currentTrack?.title ?? "No Track Playing")
                        .font(.headline)
                    Text(wsManager.currentTrack?.artist ?? "DropBeat")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            // Playback Controls
            HStack(spacing: 20) {
                Button(action: { wsManager.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                
                Button(action: {
                    if wsManager.currentTrack != nil {
                        wsManager.play()
                    }
                }) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                
                Button(action: { wsManager.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
            
            Divider()
            
            // Search Bar Placeholder
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                Text("Search")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: 300, height: 400)
    }
}