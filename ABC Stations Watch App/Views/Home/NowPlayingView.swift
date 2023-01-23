
import SwiftUI
import ComposableArchitecture

struct NowPlaying: ReducerProtocol {
    struct State: Equatable {
        enum Status: Equatable {
            case isPlaying(Station)
            case paused(Station)
            case loading(Station)
            case initial
        }
        
        var status: Status = .initial
    }
    
    enum Action: Equatable {
        case onAppear
        case update(State.Status)
        case togglePlay
    }
    
    @Dependency(\.player) var player
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await value in player.playingState.values {
                        switch value {
                        case let .loading(station):
                            await send(.update(.loading(station)))
                        case let .paused(station):
                            await send(.update(.paused(station)))
                        case .initial, .stopped:
                            await send(.update(.initial))
                        case let .playing(station, _, _, _):
                            await send(.update(.isPlaying(station)))
                        }
                    }
                }
            case let .update(status):
                state.status = status
                return .none
            case .togglePlay:
                return .fireAndForget {
                    player.togglePlay()
                }
            }
        }
    }
}

struct NowPlayingView: View {
    struct ViewState: Equatable {
        let title: String
        let description: String
        
        enum PlayButtonState {
            case play
            case pause
        }
        let playButton: PlayButtonState
        
        init(state: NowPlaying.State) {
            switch state.status {
            case let .isPlaying(station):
                title = station.title
                description = station.description
                playButton = .pause
            case .initial:
                title = "Not playing"
                description = "Select a station"
                playButton = .play
            case let .loading(station):
                title = station.title
                description = "Loading..."
                playButton = .play
            case let .paused(station):
                title = station.title
                description = station.description
                playButton = .play
            }
        }
    }
    
    let store: StoreOf<NowPlaying>
    @ObservedObject var viewStore: ViewStore<ViewState, NowPlaying.Action>
    
    init(store: StoreOf<NowPlaying>) {
        self.store = store
        viewStore = .init(store, observe: { ViewState(state: $0) })
    }
    
    var body: some View {
        VStack {
            Text(viewStore.title)
            Text(viewStore.description)
            Button {
                viewStore.send(.togglePlay)
            } label: {
                switch viewStore.playButton {
                case .play:
                    Image(systemName: "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                case .pause:
                    Image(systemName: "pause.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
            }
        }.task {
            await viewStore.send(.onAppear).finish()
        }
    }
}
