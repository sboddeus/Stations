
import SwiftUI
import ComposableArchitecture
import AVFAudio
import SwiftUINavigation
import SDWebImageSwiftUI

struct Stations: ReducerProtocol {
    struct State: Equatable {
        var stations = ABCStations
        
        struct ActiveStationState: Equatable {
            let station: RadioStation
            enum State: Equatable {
                case idle
                case playing
            }
            let state: State
        }
        var activeStation: ActiveStationState?
        
        enum Route: Equatable {
            case createStation(CreateStation.State)
            case editStation(EditStation.State)
        }
        var route: Route?
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected(RadioStation)
        }
        case delegate(Delegate)
        
        // Internal actions
        case selected(RadioStation)
        case setRoute(State.Route?)
        case showCreateStation
        case showEditStation(RadioStation)
        case delete(RadioStation)
        case onAppear
        case loaded([RadioStation])
        case playerBinding
        case setActiveStation(State.ActiveStationState?)
        case pause
        case play
        
        // Child Actions
        enum RouteAction: Equatable {
            case createStation(CreateStation.Action)
            case editStation(EditStation.Action)
        }
       case routeAction(RouteAction)
    }
    
    @Dependency(\.player) var player
    @Dependency(\.stationMaster) var stationMaster
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .playerBinding:
                struct PlayerBindingID {}
                let currentStationState = state.activeStation
                return .run { send in
                    for await value in player.playingState.values {
                        switch value {
                        case let .loading(station), let .paused(station):
                            let newState = State.ActiveStationState(
                                station: station,
                                state: .idle
                            )
                            if newState != currentStationState {
                                await send.send(.setActiveStation(newState))
                            }
                        case let .playing(station, _, _ ,_):
                            let newState = State.ActiveStationState(
                                station: station,
                                state: .playing
                            )
                            if newState != currentStationState {
                                await send.send(.setActiveStation(newState))
                            }
                        default:
                            await send.send(.setActiveStation(nil))
                        }
                    }
                }.cancellable(id: PlayerBindingID.self)
                
            case .pause:
                return .fireAndForget {
                    player.pause()
                }
                
            case .play:
                return .fireAndForget {
                    player.play()
                }
                
            case let .setRoute(route):
                state.route = route
                return .none
                
            case let .setActiveStation(activeStationState):
                state.activeStation = activeStationState
                return .none
                
            case .showCreateStation:
                state.route = .createStation(.init())
                return .none
                
            case let .showEditStation(station):
                state.route = .editStation(.init(editedStation: station))
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
                
            case let .delete(station):
                return .task {
                    await stationMaster.remove(stationId: station.id)
                    
                    return .onAppear
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
                state.stations = stations
                return .none
                
            case .routeAction(.createStation(.delegate(.stationAdded))):
                state.route = nil
                return Effect(value: .onAppear)
            
            case .routeAction(.editStation(.delegate(.stationEdited))):
                state.route = nil
                return Effect(value: .onAppear)
                
            case .routeAction:
                return .none
            }
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
    
    @ViewBuilder
    // TODO: This should become its own TCA component
    private func row(station: RadioStation) -> some View {
        Button {
            viewStore.send(.selected(station))
        } label: {
            HStack(alignment: .center) {
                ZStack {
                    Color.white
                    WebImage(url: station.imageURL)
                        .resizable()
                        .padding(2)
                        .scaledToFit()
                }
                .frame(maxWidth: 30, maxHeight: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(station.title)
                    .foregroundColor(viewStore.activeStation?.station == station ? .red : .white)
                Spacer()
                if viewStore.activeStation?.station == station {
                    if viewStore.activeStation?.state == .playing {
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
    }
    
    var body: some View {
        List {
            ForEach(viewStore.stations) { station in
                row(station: station)
                    .swipeActions(edge: .trailing) {
                        Button {
                            viewStore.send(.showEditStation(station))
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .tint(.indigo)
                        
                        Button(role: .destructive) {
                            viewStore.send(.delete(station))
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
            }
            Button {
                viewStore.send(.showCreateStation)
            } label: {
                HStack {
                    Spacer()
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
        }
    }
}
