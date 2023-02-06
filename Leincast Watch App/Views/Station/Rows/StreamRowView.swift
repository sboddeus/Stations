
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct StreamRow: ReducerProtocol {
    struct State: Equatable, Identifiable {
        let station: Stream
        
        enum ActiveState: Equatable {
            case paused
            case playing
            case loading
            case unselected
        }
        var activeState: ActiveState
        
        var id: String {
            station.id.uuidString
        }
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected
            case edit
            case delete
            case copy
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
            case .delegate:
                return .none
                
            case .playerBinding:
                let stationId = state.station.id
                struct PlayerBindingID {}
                return .run { send in
                    for await value in player.playingState.values {
                        try Task.checkCancellation()
                        
                        guard value.stationId == stationId else {
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
                }.cancellable(id: PlayerBindingID.self)
            }
        }
    }
}

struct StreamRowView: View {
    let store: StoreOf<StreamRow>
    @ObservedObject var viewStore: ViewStoreOf<StreamRow>
    
    init(store: StoreOf<StreamRow>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        Button {
            viewStore.send(.delegate(.selected))
        } label: {
            StreamRowCoreView(
                imageURL: viewStore.station.imageURL,
                title: viewStore.station.title,
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
        }
        .task {
            await viewStore.send(.playerBinding).finish()
        }
        .swipeActions(edge: .trailing) {
            Button {
                viewStore.send(.delegate(.edit))
            } label: {
                Image(systemName: "pencil")
            }
            .tint(.indigo)

            Button {
                viewStore.send(.delegate(.copy))
            } label: {
                Image(systemName: "scissors")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .leading) {
            Button(role: .destructive) {
                viewStore.send(.delegate(.delete))
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }
}

struct StreamRowCoreView<Content: View>: View {

    let imageURL: URL?
    let title: String
    let isActive: Bool
    let content: () -> Content
    init(
        imageURL: URL?,
        title: String,
        isActive: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.imageURL = imageURL
        self.title = title
        self.isActive = isActive
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center) {

            ZStack {
                Color.white
                WebImage(url: imageURL)
                    .resizable()
                    .padding(2)
                    .scaledToFit()
            }
            .frame(maxWidth: 30, maxHeight: 30)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .foregroundColor(isActive ? .white : .red)
            Spacer()

            content()
        }
    }
}
