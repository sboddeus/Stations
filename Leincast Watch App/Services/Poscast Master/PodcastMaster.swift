
import SyndiKit
import Foundation

enum PodcastMasterErrors: Error {
    case podcastAlreadyExists
}

actor PodcastMaster {

    private var filesystem: FileSystem = .default
    private var rootPath = URL(string: "Podcasts")!

    private var rootDirectory: Directory {
        filesystem.directory(
            inBase: .documents,
            path: rootPath
        )
    }

    func initialise() async {
        try? await rootDirectory.create()
    }

    private func synthesisePodcast(from url: URL) async throws -> Podcast {
        let data = try await URLSession.shared.data(from: url).0
        let decoder = SynDecoder()
        let podcastRSSFeed = try decoder.decode(data)

        let title = podcastRSSFeed.title
        let description = podcastRSSFeed.summary
        let imageURL = podcastRSSFeed.image

        let streams: [Podcast.Episode] = podcastRSSFeed.children
            .compactMap { item -> Podcast.Episode? in
            switch item.media {
              case .podcast(let podcast):
                guard let title = podcast.title else {
                    return nil
                }
                return Podcast.Episode(
                    id: podcast.enclosure.url.absoluteString,
                    title: title,
                    description: podcast.summary ?? "",
                    imageURL: podcast.image?.href ?? imageURL,
                    url: podcast.enclosure.url)
              default:
                return nil
            }
        }

        return Podcast(
            id: url.absoluteString,
            url: url,
            title: title,
            description: description,
            imageURL: imageURL,
            episodes: streams
        )
    }

    func addPodcast(at url: URL) async throws -> Podcast {
        let podcast = try await synthesisePodcast(from: url)

        let file = try await rootDirectory.file(name: podcast.id.fileNameSanitized())
        guard await !file.exists() else {
            throw PodcastMasterErrors.podcastAlreadyExists
        }

        try await file.save(podcast)

        return podcast
    }

    func refresh(podcast: Podcast) async throws -> Podcast {
        let podcast = try await synthesisePodcast(from: podcast.url)

        let file = try await rootDirectory.file(name: podcast.id.fileNameSanitized())

        try await file.save(podcast)

        return podcast
    }

    // Public Functions
    func getAllPodcasts() async -> [Podcast] {
        guard let files = try? await rootDirectory.retrieveAllFiles() else {
            return []
        }

        let nilPodcasts = await files.asyncMap {
            try? await $0.retrieve(as: Podcast.self)
        }

        return nilPodcasts.compactMap { $0 }
    }
}
