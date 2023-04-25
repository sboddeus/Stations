
import Foundation
import SwiftUI
import AVFAudio
import ComposableArchitecture
import SDWebImageSwiftUI

struct PodcastDetails: ReducerProtocol {
    struct State: Equatable {
        let id: String
        let contentURL: URL
        var hasAppeared = false
        var episodes: IdentifiedArrayOf<EpisodeRowFeature.State>
        var _episodes: [Podcast.Episode]

        init(podcast: Podcast) {
            id = podcast.id
            contentURL = podcast.url
            _episodes = podcast.episodes
            episodes = .init(
                uniqueElements: podcast.episodes.map {
                    EpisodeRowFeature.State(
                        id: $0.id,
                        title: $0.title,
                        imageURL: $0.imageURL,
                        activeState: .unselected
                    )
            })
        }

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.id == rhs.id &&
            lhs.contentURL == rhs.contentURL &&
            lhs.hasAppeared == rhs.hasAppeared &&
            lhs.episodes == rhs.episodes
        }
    }

    enum Action: Equatable {
        case onAppear
        case podcastReloaded(Podcast)

        case episode(id: EpisodeRowFeature.State.ID, action: EpisodeRowFeature.Action)
    }

    @Dependency(\.player) var player
    @Dependency(\.podcastMaster) var podcastMaster

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                return .task { [url = state.contentURL, id = state.id] in
                    let podcast = try await podcastMaster.refresh(podcastId: id, url: url)
                    return .podcastReloaded(podcast)
                }

            case let .podcastReloaded(podcast):
                state = .init(podcast: podcast)
                return .none

            case .episode(id: let id, action: .delegate(.selected)):
                guard let episode = state._episodes.first(where: { $0.id == id }) else {
                    return .none
                }

                return .fireAndForget {
                    AVAudioSession.sharedInstance().activate { _, error in
                        guard error == nil else {
                            // TODO: Deal with error
                            assertionFailure("Couldn't activate session")
                            return
                        }
                        player.play(.podcastEpisode(episode))
                    }
                }

            case .episode:
                return .none
            }
        }
        .forEach(\.episodes, action: /Action.episode(id:action:)) {
            EpisodeRowFeature()
        }
    }
}

struct PodcastDetailsView: View {
    let store: StoreOf<PodcastDetails>
    @ObservedObject var viewStore: ViewStoreOf<PodcastDetails>

    init(store: StoreOf<PodcastDetails>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        List {
            ForEachStore(self.store.scope(
                state: \.episodes,
                action: PodcastDetails.Action.episode(id:action:))
            ) { store in
                EpisodeRowView(store: store)
            }
        }.task {
            await viewStore.send(.onAppear).finish()
        }
    }
}
