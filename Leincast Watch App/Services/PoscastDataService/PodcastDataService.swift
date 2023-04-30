
import SyndiKit
import Foundation

enum PodcastDataServiceErrors: Error {
    case podcastAlreadyExists
}

struct PodcastPositions: Equatable, Codable {
    private var storage: Dictionary<String, Double>

    mutating func set(position: Double, forEpisodeId: String, inPodcastId: String) {
        let id = inPodcastId + ":" + forEpisodeId

        storage[id] = position
    }

    func position(forEpisodeId: String, inPodcastId: String) -> Double? {
        let id = inPodcastId + ":" + forEpisodeId

        return storage[id]
    }

    public init() {
        self.storage = .init()
    }
}

actor PodcastDataService {

    private var filesystem: FileSystem = .default
    private var rootPath = URL(string: "Podcasts")!

    private var rootDirectory: Directory {
        filesystem.directory(
            inBase: .documents,
            path: rootPath
        )
    }

    private lazy var playPositionFile: File = {
        return File(
            directory: rootDirectory,
            name: "podcast_play_positions",
            fileSystem: filesystem
        )
    }()

    private var playPositions: PodcastPositions = .init()

    func initialise(with player: AVAudioPlayer) async {
        try? await rootDirectory.create()
        bind(to: player)

        playPositions = (try? await playPositionFile.retrieve(as: PodcastPositions.self)) ?? .init()
    }

    private static func synthesisePodcast(from url: URL) async throws -> Podcast {
        let data = try await URLSession.shared.data(from: url).0
        let podcastRSSFeed: Feedable = try await withCheckedThrowingContinuation({ cont in
            DispatchQueue.global(qos: .background).async {
                do {
                    let decoder = SynDecoder()
                    let podcastRSSFeed = try decoder.decode(data)
                    cont.resume(returning: podcastRSSFeed)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        })

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
        let podcast = try await PodcastDataService.synthesisePodcast(from: url)

        let file = try await rootDirectory.file(name: podcast.id.fileNameSanitized())
        guard await !file.exists() else {
            throw PodcastDataServiceErrors.podcastAlreadyExists
        }

        try await file.save(podcast)

        return podcast
    }

    func delete(podcastId: String) async throws {
        let file = try await rootDirectory.file(name: podcastId.fileNameSanitized())
        try await file.delete()
    }

    func refresh(podcastId: String, url: URL) async throws -> Podcast {
        let podcast = try await PodcastDataService.synthesisePodcast(from: url)

        try Task.checkCancellation()

        let file = try await rootDirectory.file(name: podcastId.fileNameSanitized())
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

    func position(forEpisodeId: String) async -> Double? {
        playPositions.position(forEpisodeId: forEpisodeId, inPodcastId: "")
    }

    // Bindings for remembering play positions
    private var bindTask: Task<(), Never>?
    private func bind(to player: AVAudioPlayer) {
        bindTask?.cancel()
        bindTask = Task { [weak self] in
            var bindItemCount = 0
            for await value in player.playingState.values {
                switch value {
                case let .playing(.podcastEpisode(episode), _, current, _):
                    if bindItemCount % 10 == 0 {
                        await self?.set(position: current.seconds, forEpisodeId: episode.id)
                    }
                    bindItemCount += 1
                default:
                    break
                }
            }
        }
    }

    private func set(position: Double, forEpisodeId: String) async {
        playPositions.set(
            position: position,
            forEpisodeId: forEpisodeId,
            inPodcastId: ""
        )

        try? await playPositionFile.save(playPositions)
    }

    // Deinit
    deinit {
        bindTask?.cancel()
    }
}