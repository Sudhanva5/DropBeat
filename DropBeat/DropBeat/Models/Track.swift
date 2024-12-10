import Foundation

struct Track: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let albumArt: String?
    var isLiked: Bool
    let duration: Double
    
    static let empty = Track(
        id: "empty",
        title: "No Track Playing",
        artist: "No Artist",
        albumArt: nil,
        isLiked: false,
        duration: 0
    )
    
    enum CodingKeys: String, CodingKey {
        case id, title, artist, albumArt, isLiked, duration
    }
}

// MARK: - Helper extensions
extension Track {
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isPaused: Bool {
        return duration > 0 && title != "No Track Playing"
    }
} 