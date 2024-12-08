import Foundation

struct Track: Identifiable {
    let id: String
    let title: String
    let artist: String
    let albumArt: String?
    var isLiked: Bool
    let duration: Double
}