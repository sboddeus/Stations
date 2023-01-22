
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct StationRow: ReducerProtocol {
    struct State: Equatable, Identifiable {
        let station: Station
        
        enum ActiveState: Equatable {
            case idle
            case isPlaying
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
        }
        case delegate(Delegate)
        
        case play
        case pause
        
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
            }
        }
    }
}

struct StationRowView: View {
    let store: StoreOf<StationRow>
    @ObservedObject var viewStore: ViewStoreOf<StationRow>
    
    init(store: StoreOf<StationRow>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        Button {
            viewStore.send(.delegate(.selected))
        } label: {
            HStack(alignment: .center) {
                ZStack {
                    Color.white
                    WebImage(url: viewStore.station.imageURL)
                        .resizable()
                        .padding(2)
                        .scaledToFit()
                }
                .frame(maxWidth: 30, maxHeight: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(viewStore.station.title)
                    .foregroundColor(viewStore.activeState == .unselected ? .white : .red)
                Spacer()
                
                if viewStore.activeState != .unselected {
                    if viewStore.activeState == .isPlaying {
                        Image(systemName: "pause.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                            .onTapGesture {
                                viewStore.send(.pause)
                            }
                    } else {
                        Image(systemName: "play.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                            .onTapGesture {
                                viewStore.send(.play)
                            }
                    }
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                viewStore.send(.delegate(.edit))
            } label: {
                Image(systemName: "pencil")
            }
            .tint(.indigo)

            Button(role: .destructive) {
                viewStore.send(.delegate(.delete))
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }
}
