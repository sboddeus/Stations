
import SyndiKit
import Foundation

actor PodcastMaster {

    func synthesisePodcast(from url: URL) async throws -> Podcast {
        let data = try await URLSession.shared.data(from: url).0
        let decoder = SynDecoder()
        let podcastRSSFeed = try decoder.decode(data)

        let title = podcastRSSFeed.title
        let description = podcastRSSFeed.summary
        let imageURL = podcastRSSFeed.image

        let streams: [Stream] = podcastRSSFeed.children
            .compactMap { item -> Stream? in
            switch item.media {
              case .podcast(let podcast):
                guard let title = podcast.title else {
                    return nil
                }
                return Stream(
                    id: .init(),
                    title: title,
                    description: podcast.summary ?? "",
                    imageURL: podcast.image?.href ?? imageURL,
                    url: podcast.enclosure.url)
              default:
                return nil
            }
        }

        return Podcast(
            id: UUID(),
            url: url,
            title: title,
            description: description,
            imageURL: imageURL,
            streams: streams
        )
    }
}
