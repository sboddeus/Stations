
import SwiftUI
import ComposableArchitecture
import AVFAudio
import SwiftUINavigation
import SDWebImageSwiftUI

struct Stations: ReducerProtocol {
    struct State: Equatable {
        var stations: IdentifiedArrayOf<StationRow.State> = .init(
            uniqueElements: ABCStations.map {
                StationRow.State(station: $0, activeState: .unselected)
            }
        )
        
        enum Route: Equatable {
            case createStation(CreateStation.State)
            case editStation(EditStation.State)
        }
        var route: Route?
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected(Station)
        }
        case delegate(Delegate)

        // Internal actions
        case setRoute(State.Route?)
        case showCreateStation
        case onAppear
        case loaded([Station])
        case playerBinding

        // Child Actions
        enum RouteAction: Equatable {
            case createStation(CreateStation.Action)
            case editStation(EditStation.Action)
        }
        case routeAction(RouteAction)
        
        case station(id: StationRow.State.ID, action: StationRow.Action)
    }
    
    @Dependency(\.player) var player
    @Dependency(\.stationMaster) var stationMaster
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            // NOTE: Do player binding at this level in the hopes of being more efficient
            // then doing it at the row level
            case .playerBinding:
                let stations = state.stations
                struct PlayerBindingID {}
                return .run { send in
                    for await value in player.playingState.values {
                        try Task.checkCancellation()
                        switch value {
                        case let .loading(station), let .paused(station):
                            await send.send(.station(id: station.id, action: .setActiveState(.idle)))
                        case let .playing(station, _, _ ,_):
                            await send.send(.station(id: station.id, action: .setActiveState(.isPlaying)))
                        default:
                            for station in stations {
                                await send.send(.station(id: station.id, action: .setActiveState(.unselected)))
                            }
                        }
                    }
                }.cancellable(id: PlayerBindingID.self, cancelInFlight: true)
                
            case let .setRoute(route):
                state.route = route
                return .none
                
            case .showCreateStation:
                state.route = .createStation(.init())
                return .none
                
            case let .station(id, action: .delegate(.edit)):
                if let station = state.stations[id: id]?.station {
                    state.route = .editStation(.init(editedStation: station))
                }
                return .none
                
            case let .station(id, action: .delegate(.delete)):
                return .task {
                    // Stop playing the station if it is playing
                    if player.currentItem?.id == id {
                        player.stop()
                    }
                    
                    // Then remove it from station master
                    await stationMaster.remove(stationId: id)
                    
                    return .onAppear
                }
                
            case let .station(id, action: .delegate(.selected)):
                if let station = state.stations[id: id]?.station {
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
                } else {
                    return .none
                }
                
            case .delegate:
                return .none
                
            case .onAppear:
                return .task {
                    let stations = await stationMaster
                        .getStations()
                        .sorted { $0.title < $1.title }
                    
                    return .loaded(stations)
                }
                
            case let .loaded(stations):
                state.stations = .init(
                    uniqueElements: stations.map { .init(
                        station: $0,
                        activeState: .unselected
                    )}
                )
                return .none
                
            case .routeAction(.createStation(.delegate(.stationAdded))):
                state.route = nil
                return Effect(value: .onAppear)
            
            case .routeAction(.editStation(.delegate(.stationEdited))):
                // TODO: If the station edited was the currently playing station then reload it.
                state.route = nil
                return Effect(value: .onAppear)
                
            case .routeAction:
                return .none
                
            case .station:
                return .none
            }
        }
        .forEach(\.stations, action: /Action.station) {
            StationRow()
        }
        .ifLet(\.route, action: /Action.routeAction) {
            Scope(state: /State.Route.createStation, action: /Action.RouteAction.createStation) {
                CreateStation()
            }
            Scope(state: /State.Route.editStation, action: /Action.RouteAction.editStation) {
                EditStation()
            }
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
        List {
            ForEachStore(
                store.scope(
                    state: \.stations,
                    action: Stations.Action.station(id:action:))
            ) { store in
                StationRowView(store: store)
            }
            
            Button {
                viewStore.send(.showCreateStation)
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.green)
                    Text("Add")
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
        .task {
            await viewStore.send(.playerBinding).finish()
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Stations.Action.setRoute
            ),
            case: /Stations.State.Route.createStation
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Stations.Action.routeAction(.createStation($0)) }
            )
            CreateStationView(store: store)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Stations.Action.setRoute
            ),
            case: /Stations.State.Route.editStation
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Stations.Action.routeAction(.editStation($0)) }
            )
            EditStationView(store: store)
                .interactiveDismissDisabled()
        }
    }
}
