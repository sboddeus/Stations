
import Foundation

struct Podcast: Equatable, Identifiable, Codable {

    struct Episode: Equatable, Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let imageURL: URL?
        let url: URL
    }

    let id: String
    let url: URL
    let title: String
    let description: String?
    let imageURL: URL?
    let episodes: [Episode]
}
