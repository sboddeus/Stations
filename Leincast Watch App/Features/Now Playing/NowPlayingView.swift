
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI
import AVFAudio

struct NowPlaying: Reducer {
    struct State: Equatable {
        enum Status: Equatable {
            case isPlaying(MediaItem)
            case paused(MediaItem)
            case loading(MediaItem)
            case initial
        }
        
        var status: Status = .initial
        var isVolumeFocused: Bool = false
        var volume: Double = 0
        var showVolumeCaption = false
        var context: PresentationContext = .embedded
        var showSkipButtons = false
        var showPlayPosition = false
        var playPosition: Double?
    }
    
    enum Action: Equatable {
        case setPresentationContext(PresentationContext)
        case playBinding
        case update(State.Status)
        case togglePlay
        case toggleVolumeControl
        case updateVolume(Double)
        case updatePlayPosition(Double?)
        case skipForward
        case skipBackward
    }
    
    @Dependency(\.player) var player
    @Dependency(\.streamDataService) var streamDataService
    @Dependency(\.userDefaults) var userDefaults
    
    static let volumeCaptionUserDefaultsKey = "volume.caption"
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .updatePlayPosition(position):
                state.playPosition = position
                return .none

            case let .setPresentationContext(context):
                state.context = context
                switch context {
                case .embedded:
                    state.showVolumeCaption = (userDefaults.value(
                        forKey: Self.volumeCaptionUserDefaultsKey
                    ) as? Bool) ?? true
                case .fullScreen:
                    state.showVolumeCaption = false
                }
                return .none
                
            case .playBinding:
                return .run { send in
                        for await value in player.playingState.values {
                            switch value {
                            case let .loading(station):
                                await send(.update(.loading(station)))
                            case let .paused(station):
                                await send(.update(.paused(station)))
                            case .initial, .stopped:
                                await send(.update(.initial))
                            case let .playing(station, total, current, _):
                                await send(.update(.isPlaying(station)))
                                switch station {
                                case .podcastEpisode:
                                    let playPercentage = current.seconds / total.seconds
                                    await send(.updatePlayPosition(playPercentage))
                                case .stream:
                                    await send(.updatePlayPosition(nil))
                                }
                            }
                        }
                    }
                
            case let .update(status):
                state.status = status
                if state.volume != streamDataService.volume {
                    state.volume = streamDataService.volume
                }
                return .none
                
            case .togglePlay:
                return .run { _ in
                    player.togglePlay()
                }
                
            case .toggleVolumeControl:
                state.showVolumeCaption = false
                state.isVolumeFocused.toggle()
                return .run { _ in
                    userDefaults.set(false, forKey: Self.volumeCaptionUserDefaultsKey)
                }
                
            case let .updateVolume(volume):
                state.volume = volume
                return .none

            case .skipBackward:
                return .run { _ in
                    player.seekBackward()
                }

            case .skipForward:
                return .run { _ in
                    player.seekForward()
                }
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
        let showVolumeCaption: Bool
        var showSkipButtons: Bool
        var showPlayPosition: Bool
        var progressPercentage: Double
        
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
                description = station.description ?? ""
                playButton = .pause
                imageURL = station.imageURL
                showSkipButtons = !station.isLiveContent
                showPlayPosition = !station.isLiveContent
            case .initial:
                title = "Not playing"
                description = "Select a station"
                playButton = .hidden
                imageURL = nil
                showSkipButtons = false
                showPlayPosition = false
                progressPercentage = 0
            case let .loading(station):
                title = station.title
                description = "Loading..."
                playButton = .play
                imageURL = station.imageURL
                showSkipButtons = !station.isLiveContent
                showPlayPosition = !station.isLiveContent
            case let .paused(station):
                title = station.title
                description = station.description ?? ""
                playButton = .play
                imageURL = station.imageURL
                showSkipButtons = !station.isLiveContent
                showPlayPosition = !station.isLiveContent
            }
            
            // Volume is focused if isVolumeFocused or if the presentatio context is full screen
            isVolumeFocused = state.isVolumeFocused || state.context == .fullScreen
            volume = state.volume
            showVolumeCaption = state.showVolumeCaption
            progressPercentage = state.playPosition ?? 0
        }
    }
    
    let store: StoreOf<NowPlaying>
    @ObservedObject var viewStore: ViewStore<ViewState, NowPlaying.Action>
    
    @Environment(\.presentationContext) var presentationContext
    
    init(store: StoreOf<NowPlaying>) {
        self.store = store
        viewStore = .init(store, observe: { ViewState(state: $0) })
    }

    var playControls: some View {
        HStack(spacing: 10) {
            Spacer()
            if viewStore.showSkipButtons {
                Button {
                    viewStore.send(.skipBackward)
                } label: {
                    Image(systemName: "gobackward.30")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.secondary)
                        .frame(width: 25, height: 25)
                        .padding()
                }
                .clipShape(Circle())
                .frame(width: 25, height: 25)
            }
            Button {
                viewStore.send(.togglePlay)
            } label: {
                ZStack {
                    Circle()
                        .trim(from: 0, to: viewStore.progressPercentage) // 1
                        .stroke(
                            LeincastColors.brand.color.opacity(0.5),
                            lineWidth: 4
                        )
                        .frame(width: 42, height: 42)
                    switch viewStore.playButton {
                    case .play:
                        Image(systemName: "play.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(LeincastColors.brand.color)
                            .frame(width: 25, height: 25)
                            .padding()
                    case .pause:
                        Image(systemName: "pause.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(LeincastColors.brand.color)
                            .frame(width: 25, height: 25)
                            .padding()
                    case .hidden:
                        EmptyView()
                    }
                }
            }
            .clipShape(Circle())
            if viewStore.showSkipButtons {
                Button {
                    viewStore.send(.skipForward)
                } label: {
                    Image(systemName: "goforward.30")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.secondary)
                        .frame(width: 25, height: 25)
                        .padding()
                }
                .clipShape(Circle())
                .frame(width: 25, height: 25)
                Spacer()
            }
        }
    }

    var controlStack: some View {
        VStack(spacing: 10) {
            playControls
            VStack {
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
                }
                if viewStore.state.showVolumeCaption {
                    Text("Tap to control volume with digital crown. Tap again to scroll with digital crown.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

            }.onTapGesture {
                viewStore.send(.toggleVolumeControl)
            }
        }
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
                    controlStack
                }
            }
        }
        .onAppear {
            viewStore.send(.setPresentationContext(presentationContext))
        }
        .task {
            await viewStore.send(.playBinding).finish()
        }
        .background {
            if viewStore.isVolumeFocused {
                VolumeView().opacity(0)
            }
        }
    }
}
