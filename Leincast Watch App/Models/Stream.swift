
import Foundation

struct Stream: Equatable, Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let imageURL: URL?
    let url: URL
}
