
import Foundation

enum MediaItem: Equatable, Codable {
    case stream(Stream)
    case podcast(Podcast)
}

extension MediaItem: Identifiable {
    var id: String {
        switch self {
        case let .podcast(podcast): return podcast.id
        case let .stream(stream): return stream.id
        }
    }
}
