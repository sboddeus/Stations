
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct EpisodeRowFeature: Reducer {
    struct State: Equatable, Identifiable {
        let episode: Podcast.Episode

        enum ActiveState: Equatable {
            case paused
            case playing
            case loading
            case unselected
        }
        var activeState: ActiveState

        var id: String {
            episode.id
        }
    }

    enum Action: Equatable {

        enum Delegate: Equatable {
            case selected
        }
        case delegate(Delegate)

        case play
        case pause

        case playerBinding

        case setActiveState(State.ActiveState)
    }

    @Dependency(\.player) var player

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setActiveState(activeState):
                state.activeState = activeState
                return .none

            case .play:
                return .run { _ in
                    player.play()
                }

            case .pause:
                return .run { _ in
                    player.pause()
                }

            case .playerBinding:
                let itemId = state.id
                return .run { send in
                    for await value in player.playingState.values {
                        guard value.stationId == itemId else {
                            await send(.setActiveState(.unselected))
                            continue
                        }

                        switch value {
                        case .loading:
                            await send(.setActiveState(.loading))
                        case .paused:
                            await send(.setActiveState(.paused))
                        case .playing:
                            await send(.setActiveState(.playing))
                        case .initial, .stopped:
                            await send(.setActiveState(.unselected))
                        }
                    }
                }

            case .delegate:
                return .none
            }
        }
    }
}

struct EpisodeRowView: View {
    let store: StoreOf<EpisodeRowFeature>
    @ObservedObject var viewStore: ViewStoreOf<EpisodeRowFeature>

    init(store: StoreOf<EpisodeRowFeature>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        Button {
            viewStore.send(.delegate(.selected))
        } label: {
            StreamRowCoreView(
                imageURL: viewStore.episode.imageURL,
                title: viewStore.episode.title,
                isActive: viewStore.activeState == .unselected) {
                    switch viewStore.activeState {
                    case .loading:
                        ProgressView()
                            .foregroundColor(.red)
                            .scaledToFit()
                            .fixedSize()
                    case .playing:
                        Image(systemName: "pause.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                            .onTapGesture {
                                viewStore.send(.pause)
                            }
                    case .paused:
                        Image(systemName: "play.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                            .onTapGesture {
                                viewStore.send(.play)
                            }
                    case .unselected:
                        EmptyView()
                    }
            }
            .task {
                await viewStore.send(.playerBinding).finish()
            }
        }
    }
}


