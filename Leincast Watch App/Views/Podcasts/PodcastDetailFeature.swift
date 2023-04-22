
import Foundation
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct PodcastDetails: ReducerProtocol {
    struct State: Equatable {
        var podcast: Podcast
        var hasAppeared = false
    }

    enum Action: Equatable {
        case play(Stream)
        case onAppear
        case podcastReloaded(Podcast)
    }

    @Dependency(\.player) var player
    @Dependency(\.podcastMaster) var podcastMaster

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .play(stream):
                return .fireAndForget {
                    player.play(stream)
                }

            case .onAppear:
                guard !state.hasAppeared else { return .none }
                return .task { [podcast = state.podcast] in
                    let podcast = try await podcastMaster.refresh(podcast: podcast)
                    return .podcastReloaded(podcast)
                }

            case let .podcastReloaded(podcast):
                state.podcast = podcast
                return .none
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
                HStack {
                    WebImage(url: episode.imageURL)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 30, maxHeight: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(episode.title)

                    Spacer()
                }
                .onTapGesture {
                    viewStore.send(.play(episode))
                }
            }
        }
    }
}
