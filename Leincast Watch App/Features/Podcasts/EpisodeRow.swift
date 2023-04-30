
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct EpisodeRowFeature: ReducerProtocol {
    struct State: Equatable, Identifiable {
        let id: String
        let title: String
        let imageURL: URL?

        enum ActiveState: Equatable {
            case paused
            case playing
            case loading
            case unselected
        }
        var activeState: ActiveState
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

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setActiveState(activeState):
                state.activeState = activeState
                return .none

            case .play:
                return .fireAndForget {
                    player.play()
                }

            case .pause:
                return .fireAndForget {
                    player.pause()
                }

            case .playerBinding:
                let itemId = state.id
                return .run { send in
                    for await value in player.playingState.values {
                        guard value.stationId == itemId else {
                            await send.send(.setActiveState(.unselected))
                            continue
                        }

                        switch value {
                        case .loading:
                            await send.send(.setActiveState(.loading))
                        case .paused:
                            await send.send(.setActiveState(.paused))
                        case .playing:
                            await send.send(.setActiveState(.playing))
                        case .initial, .stopped:
                            await send.send(.setActiveState(.unselected))
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
                imageURL: viewStore.imageURL,
                title: viewStore.title,
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

