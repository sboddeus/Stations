
import SwiftUI
import ComposableArchitecture
import AVFAudio
import SwiftUINavigation

struct Stations: ReducerProtocol {
    struct State: Equatable {
        var stations = ABCStations
        var selectedStation: RadioStation?
        var createStation: CreateStation.State?
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected(RadioStation)
        }
        case delegate(Delegate)
        
        // Internal actions
        case selected(RadioStation)
        case showCreateStation(Bool)
        
        // Child Actions
        case createStation(CreateStation.Action)
    }
    
    @Dependency(\.player) var player
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .showCreateStation(show):
                state.createStation = show ? .init() : nil
                return .none
                
            case let .selected(station):
                return .concatenate(
                    .run { send in
                        AVAudioSession.sharedInstance().activate { _, error in
                            guard error == nil else {
                                // TODO: Deal with error
                                assertionFailure("Couldn't activate session")
                                return
                            }

                            Task {
                                player.play(station)
                                await send(.delegate(.selected(station)))
                            }
                        }
                    }
                )
                
            case .delegate:
                return .none
                
            case .createStation:
                return .none
            }
        }.ifLet(\.createStation, action: /Action.createStation) {
            CreateStation()
        }
    }
}

struct StationsView: View {
    let store: StoreOf<Stations>
    @ObservedObject var viewStore: ViewStoreOf<Stations>
    
    init(store: StoreOf<Stations>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(viewStore.stations) { station in
                    Button {
                        viewStore.send(.selected(station))
                    } label: {
                        Text(station.title)
                            .foregroundColor(viewStore.selectedStation == station ? .red : .white)
                    }
                }
                Button {
                    viewStore.send(.showCreateStation(true))
                } label: {
                    Text("Add")
                }
            }
        }.fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.createStation,
                send: { .showCreateStation($0 != nil) }
            )) {
                viewStore.send(.showCreateStation(false))
            } content: { value in
                let store = self.store.scope { _ in
                    value.wrappedValue
                } action: { action in
                    Stations.Action.createStation(action)
                }
                CreateStationView(store: store)
            }
    }
}
