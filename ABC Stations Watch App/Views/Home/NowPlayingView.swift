
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI
import AVFAudio

struct NowPlaying: ReducerProtocol {
    struct State: Equatable {
        enum Status: Equatable {
            case isPlaying(Station)
            case paused(Station)
            case loading(Station)
            case initial
        }
        
        var status: Status = .initial
        var isVolumeFocused: Bool = false
        var volume: Double = 0
    }
    
    enum Action: Equatable {
        case onAppear
        case update(State.Status)
        case togglePlay
        case toggleVolumeControl
        case updateVolume(Double)
    }
    
    @Dependency(\.player) var player
    @Dependency(\.streamMaster) var stationMaster
    
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
                if state.volume != stationMaster.volume {
                    state.volume = stationMaster.volume
                }
                return .none
                
            case .togglePlay:
                return .fireAndForget {
                    player.togglePlay()
                }
                
            case .toggleVolumeControl:
                state.isVolumeFocused.toggle()
                return .none
                
            case let .updateVolume(volume):
                state.volume = volume
                return .none
            }
        }
    }
}

struct NowPlayingView: View {
    struct ViewState: Equatable {
        let title: String
        let description: String
        let imageURL: URL?
        let isVolumeFocused: Bool
        let volume: Double
        
        enum PlayButtonState {
            case play
            case pause
            case hidden
        }
        let playButton: PlayButtonState
        
        init(state: NowPlaying.State) {
            switch state.status {
            case let .isPlaying(station):
                title = station.title
                description = station.description
                playButton = .pause
                imageURL = station.imageURL
            case .initial:
                title = "Not playing"
                description = "Select a station"
                playButton = .hidden
                imageURL = nil
            case let .loading(station):
                title = station.title
                description = "Loading..."
                playButton = .play
                imageURL = station.imageURL
            case let .paused(station):
                title = station.title
                description = station.description
                playButton = .play
                imageURL = station.imageURL
            }
            
            isVolumeFocused = state.isVolumeFocused
            volume = state.volume
        }
    }
    
    let store: StoreOf<NowPlaying>
    @ObservedObject var viewStore: ViewStore<ViewState, NowPlaying.Action>
    
    init(store: StoreOf<NowPlaying>) {
        self.store = store
        viewStore = .init(store, observe: { ViewState(state: $0) })
    }
    
    var body: some View {
        ZStack {
            if let imageURL = viewStore.imageURL {
                ZStack {
                    Color.white
                    WebImage(url: imageURL)
                        .resizable()
                        .padding(2)
                        .scaledToFit()
                        .frame(maxHeight: 100)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
                .brightness(-0.8)
                .blur(radius: 1)
            }
            VStack(alignment: .leading) {
                Text(viewStore.title)
                    .font(.title3)
                    .foregroundColor(.primary)
                Text(viewStore.description)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.7)
                if viewStore.playButton != .hidden {
                    VStack(spacing: 10) {
                        Button {
                            viewStore.send(.togglePlay)
                        } label: {
                            switch viewStore.playButton {
                            case .play:
                                Image(systemName: "play.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(LeincastColors.brand.color)
                                    .frame(width: 30, height: 30)
                                    .padding()
                            case .pause:
                                Image(systemName: "pause.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(LeincastColors.brand.color)
                                    .frame(width: 30, height: 30)
                                    .padding()
                            case .hidden:
                                EmptyView()
                            }
                        }
                        .clipShape(Circle())
                        HStack {
                            Group {
                                if viewStore.isVolumeFocused {
                                    Image(systemName: "speaker.fill")
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "speaker")
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                            .foregroundColor(LeincastColors.brand.color)
                            .frame(width: 15, height: 15)
                            
                            ProgressView(value: viewStore.volume, total: 1)
                                .frame(maxHeight: 2)
                                .opacity(viewStore.isVolumeFocused ? 1 : 0.5)
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(LeincastColors.brand.color)
                           
                        }.onTapGesture {
                            viewStore.send(.toggleVolumeControl)
                        }
                    }
                }
            }
        }
        .task {
            await viewStore.send(.onAppear).finish()
        }
        .background {
            if viewStore.isVolumeFocused {
                VolumeView().opacity(0)
            }
        }
    }
}
