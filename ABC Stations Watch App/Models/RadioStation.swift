
import Foundation

// MARK: - Radio Station

struct APITimeZone: Equatable {
    let code: String
    let name: String
    let offset: Double
}

struct RadioStation: Equatable, Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let imageURL: URL?
    let url: URL
    //let timeZone: APITimeZone
}
