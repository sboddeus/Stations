
import Foundation

enum MediaItem: Equatable, Codable {
    case stream(Stream)
    case podcastEpisode(Podcast.Episode)
}

extension MediaItem: Identifiable {
    var id: String {
        switch self {
        case let .podcastEpisode(podcast): return podcast.id
        case let .stream(stream): return stream.id
        }
    }

    var title: String {
        switch self {
        case let .podcastEpisode(podcast): return podcast.title
        case let .stream(stream): return stream.title
        }
    }

    var description: String? {
        switch self {
        case let .podcastEpisode(podcast): return podcast.description
        case let .stream(stream): return stream.description
        }
    }

    var url: URL {
        switch self {
        case let .podcastEpisode(podcast): return podcast.url
        case let .stream(stream): return stream.url
        }
    }

    var imageURL: URL? {
        switch self {
        case let .podcastEpisode(podcast): return podcast.imageURL
        case let .stream(stream): return stream.imageURL
        }
    }
}

extension MediaItem {
    var isLiveContent: Bool {
        switch self {
        case .podcastEpisode: return false
        case .stream: return true
        }
    }
}
