
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

    private static func synthesisePodcast(from url: URL) async throws -> Podcast {
        let data = try await URLSession.shared.data(from: url).0
        let decoder = SynDecoder()
        let podcastRSSFeed = try decoder.decode(data)

        let title = podcastRSSFeed.title
        let description = podcastRSSFeed.summary
        var imageURL = podcastRSSFeed.image

        let streams: [Podcast.Episode] = podcastRSSFeed.children
            .compactMap { item -> Podcast.Episode? in
            switch item.media {
              case .podcast(let podcast):
                return Podcast.Episode(
                    id: podcast.enclosure.url.absoluteString,
                    title: podcast.title ?? item.title,
                    description: (podcast.summary ?? item.summary) ?? "",
                    imageURL: (podcast.image?.href ?? item.imageURL) ?? imageURL,
                    url: podcast.enclosure.url)
              default:
                return nil
            }
        }

        if imageURL == nil {
            imageURL = streams.first(where: { $0.imageURL != nil })?.imageURL
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
        let podcast = try await PodcastMaster.synthesisePodcast(from: url)

        let file = try await rootDirectory.file(name: podcast.id.fileNameSanitized())
        guard await !file.exists() else {
            throw PodcastMasterErrors.podcastAlreadyExists
        }

        try await file.save(podcast)

        return podcast
    }

    func delete(podcast: Podcast) async throws {
        let file = try await rootDirectory.file(name: podcast.id.fileNameSanitized())
        try await file.delete()
    }

    func refresh(podcast: Podcast) async throws -> Podcast {
        let podcast = try await PodcastMaster.synthesisePodcast(from: podcast.url)

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
