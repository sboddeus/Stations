
import Foundation
import SwiftUI
import ComposableArchitecture

struct Podcasts: ReducerProtocol {
    struct State: Equatable {
        var podcasts: [Podcast] = []
        var podcastDetails: PodcastDetails.State?
    }

    enum Action: Equatable {
        case onAppear
        case setPodcasts([Podcast])
        case selected(Podcast)
        case setPodcastDetails(PodcastDetails.State?)
        case podcastDetails(PodcastDetails.Action)
    }

    @Dependency(\.podcastMaster) var podcastMaster

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .task {
                    let podcast = try await podcastMaster.synthesisePodcast(from: URL(string: "https://cdn.atp.fm/rss/public?x0h3nk5k")!)

                    return .setPodcasts([podcast])
                }

            case let .setPodcasts(podcasts):
                state.podcasts = podcasts
                return .none

            case let .selected(podcast):
                state.podcastDetails = .init(podcast: podcast)
                return .none

            case let .setPodcastDetails(detailState):
                state.podcastDetails = detailState
                return .none

            case .podcastDetails:
                return .none
            }
        }.ifLet(\.podcastDetails, action: /Action.podcastDetails) {
            PodcastDetails()
        }
    }
}

struct PodcastsView: View {
    let store: StoreOf<Podcasts>
    @ObservedObject var viewStore: ViewStoreOf<Podcasts>

    init(store: StoreOf<Podcasts>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        List {
            ForEach(viewStore.podcasts) { podcast in
                Text(podcast.title)
                    .onTapGesture {
                        viewStore.send(.selected(podcast))
                    }
            }
        }
        .navigationDestination(
            unwrapping: viewStore.binding(
                get: \.podcastDetails,
                send: Podcasts.Action.setPodcastDetails
            )) { $binding in
                let store = store.scope(
                    state: { $0.podcastDetails ?? binding },
                    action: { Podcasts.Action.podcastDetails($0) }
                )
                PodcastDetailsView(store: store)
            }
        .onAppear {
            viewStore.send(.onAppear)
        }
    }
}

struct PodcastDetails: ReducerProtocol {
    struct State: Equatable {
        var podcast: Podcast
    }

    enum Action: Equatable {
        case play(Stream)
    }

    @Dependency(\.player) var player

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .play(stream):
                return .fireAndForget {
                    player.play(stream)
                }
            }
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
            ForEach(viewStore.podcast.streams) { episode in
                Text(episode.title)
                    .onTapGesture {
                        viewStore.send(.play(episode))
                    }
            }
        }
    }
}
