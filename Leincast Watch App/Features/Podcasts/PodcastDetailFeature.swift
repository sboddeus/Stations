
import Foundation
import SwiftUI
import AVFAudio
import ComposableArchitecture
import SDWebImageSwiftUI

struct PodcastDetails: ReducerProtocol {
    struct State: Equatable {
        let id: String
        var hasAppeared = false
        var isLoading = true
        var episodes: IdentifiedArrayOf<EpisodeRowFeature.State>
        var nextCursor: String?

        init(id: String) {
            self.id = id
            self.episodes = []
        }
    }

    enum Action: Equatable {
        case onAppear
        case episodesLoaded([Podcast.Episode], nextCursor: String?)

        case episode(id: EpisodeRowFeature.State.ID, action: EpisodeRowFeature.Action)
        case loadNextCursor
    }

    @Dependency(\.player) var player
    @Dependency(\.podcastDataService) var podcastDataService

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                return
                    .concatenate(
                        .task { [state] in
                            let episodes = await podcastDataService.getAllEpisodes(forPodcastId: state.id)
                            return .episodesLoaded(episodes?.episodes ?? [], nextCursor: episodes?.nextCursor)
                        },
                        .task { [id = state.id] in
                            _ = try await podcastDataService.refresh(podcastId: id)
                            let episodes = await podcastDataService.getAllEpisodes(forPodcastId: id)
                            return .episodesLoaded(episodes?.episodes ?? [], nextCursor: episodes?.nextCursor)
                        }
                    )

            case let .episodesLoaded(episodes, nextCursor):
                state.isLoading = false
                if state.nextCursor == nil {
                    state.episodes = .init(
                        uniqueElements: episodes.map {
                            .init(episode: $0, activeState: .unselected)
                        }
                    )
                } else {
                    episodes.forEach {
                        state.episodes.updateOrAppend(.init(episode: $0, activeState: .unselected))
                    }
                }

                state.nextCursor = nextCursor
                return .none

            case .episode(id: let id, action: .delegate(.selected)):
                guard let episode = state.episodes[id: id]?.episode else {
                    return .none
                }

                return .fireAndForget {
                    AVAudioSession.sharedInstance().activate { _, error in
                        guard error == nil else {
                            // TODO: Deal with error
                            assertionFailure("Couldn't activate session")
                            return
                        }

                        Task {
                            let position = await podcastDataService.position(forEpisodeId: episode.id)
                            player.play(.podcastEpisode(episode), fromPosition: position)
                        }
                    }
                }

            case .episode:
                return .none

            case .loadNextCursor:
                return .task { [state] in
                    let episodes = await podcastDataService.getAllEpisodes(forPodcastId: state.id, cursor: state.nextCursor)
                    return .episodesLoaded(episodes?.episodes ?? [], nextCursor: episodes?.nextCursor)
                }
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
            if viewStore.isLoading {
                ProgressView().progressViewStyle(.circular)
            } else {
                ForEachStore(self.store.scope(
                    state: \.episodes,
                    action: PodcastDetails.Action.episode(id:action:))
                ) { store in
                    EpisodeRowView(store: store)
                }

                if viewStore.nextCursor != nil {
                    ProgressView().progressViewStyle(.circular)
                        .onAppear {
                            viewStore.send(.loadNextCursor)
                        }
                }
            }
        }.task {
            await viewStore.send(.onAppear).finish()
        }
    }
}
