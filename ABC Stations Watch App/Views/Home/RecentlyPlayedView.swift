
import SwiftUI
import ComposableArchitecture
import AVFAudio

struct RecentlyPlayed: ReducerProtocol {
    struct State: Equatable {
        var stations: IdentifiedArrayOf<StationRow.State> = []
    }
    
    enum Action: Equatable {
        case onAppear
        case update([Station])
        case station(id: StationRow.State.ID, action: StationRow.Action)
    }
    
    @Dependency(\.stationMaster) var stationMaster
    @Dependency(\.player) var player
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .task {
                    let recents = await stationMaster.recents()
                    return .update(recents)
                }
            case let .update(stations):
                state.stations = IdentifiedArray(
                    uniqueElements: stations.map {
                        StationRow.State(station: $0, activeState: .unselected)
                    }
                )
                return .none
            case let .station(id, .delegate(.selected)):
                if let station = state.stations[id: id] {
                    return .fireAndForget {
                        AVAudioSession.sharedInstance().activate { _, error in
                            guard error == nil else {
                                // TODO: Deal with error
                                assertionFailure("Couldn't activate session")
                                return
                            }
                            
                            player.play(station.station)
                        }
                        
                    }
                }
                return .none
                
            case .station:
                return .none
            }
        }
        .forEach(\.stations, action: /Action.station) {
            StationRow()
        }
    }
}

struct RecentlyPlayedView: View {
    let store: StoreOf<RecentlyPlayed>
    @ObservedObject var viewStore: ViewStoreOf<RecentlyPlayed>
    
    init(store: StoreOf<RecentlyPlayed>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        VStack {
            if viewStore.stations.isEmpty {
                Text("No streams played yet").font(.body)
            }
            ForEachStore(
                store.scope(
                    state: \.stations,
                    action: RecentlyPlayed.Action.station(id:action:))
            ) { store in
                StationRowView(store: store)
            }
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
    }
}
