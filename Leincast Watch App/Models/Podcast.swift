
import Foundation

struct Podcast: Equatable, Identifiable, Codable {
    let id: UUID
    let url: URL
    let title: String
    let description: String?
    let imageURL: URL?
    let streams: [Stream]
}
