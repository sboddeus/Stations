
import Foundation

struct Stream: Equatable, Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let imageURL: URL?
    let url: URL
}
