
import SwiftUI
import ComposableArchitecture
import AVFAudio
import SwiftUINavigation
import SDWebImageSwiftUI

struct Stations: ReducerProtocol {
    struct State: Equatable {
        var rootDirectory: Directory
        
        init(rootDirectory: Directory) {
            self.rootDirectory = rootDirectory
        }
        
        var isLoading = true
        var stations: IdentifiedArrayOf<StationRow.State> = []
        var directories: IdentifiedArrayOf<DirectoryRow.State> = []
        
        indirect enum Route: Equatable {
            case createStation(CreateStation.State)
            case editStation(EditStation.State)
            case createDirectory(CreateDirectory.State)
            case editDirectory(EditDirectory.State)
            case subDirectory(Stations.State)
        }
        var route: Route?
    }
    
    indirect enum Action: Equatable {
        enum Delegate: Equatable {
            case selected(Station)
        }
        case delegate(Delegate)

        // Internal actions
        case setRoute(State.Route?)
        case showCreateStation
        case showCreateDirectory
        case onAppear
        case loadedStations([Station])
        case loadedSubDirectories([Directory])

        // Child Actions
        indirect enum RouteAction: Equatable {
            case createStation(CreateStation.Action)
            case editStation(EditStation.Action)
            case subDirectory(Stations.Action)
            case editDirectory(EditDirectory.Action)
            case createDirectory(CreateDirectory.Action)
        }
        case routeAction(RouteAction)
        
        case station(id: StationRow.State.ID, action: StationRow.Action)
        case directory(id: DirectoryRow.State.ID, action: DirectoryRow.Action)
    }
    
    @Dependency(\.player) var player
    @Dependency(\.stationMaster) var stationMaster
    
    private var core: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
                
            case let .setRoute(route):
                state.route = route
                return .none
                
            case .showCreateStation:
                state.route = .createStation(
                    .init(
                        containingDirectory: state.rootDirectory
                    )
                )
                return .none
                
            case .showCreateDirectory:
                state.route = .createDirectory(
                    .init(
                        containingDirectory: state.rootDirectory
                    )
                )
                return .none
                
            case let .station(id, action: .delegate(.edit)):
                if let station = state.stations[id: id]?.station {
                    state.route = .editStation(
                        .init(
                            editedStation: station,
                            containingDirectory: state.rootDirectory
                        )
                    )
                }
                return .none
                
            case let .station(id, action: .delegate(.delete)):
                return .task { [state] in
                    // Stop playing the station if it is playing
                    if player.currentItem?.id.uuidString == id {
                        player.stop()
                    }
                    
                    // TODO: Deal with error
                    try await state.rootDirectory.file(name: id).delete()
                    
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
                struct OnAppearID {}
                return .run { [directory = state.rootDirectory] send in
                    let stations = await directory.getAllStations()
                    
                    await send(.loadedStations(stations))
                    
                    let directories = (try? await directory.retrieveAllSubDirectories()) ?? []
                    
                    await send(.loadedSubDirectories(directories))
                }.cancellable(id: OnAppearID.self, cancelInFlight: true)
                
            case let .loadedStations(stations):
                state.stations = .init(
                    uniqueElements: stations.map { .init(
                        station: $0,
                        activeState: .unselected
                    )}
                )
                return .none
                
            case let .loadedSubDirectories(directories):
                state.directories = .init(
                    uniqueElements: directories.map {
                        .init(directory: $0)
                    }
                )
                return .none
                
            case .routeAction(.createStation(.delegate(.stationAdded))):
                state.route = nil
                return Effect(value: .onAppear)
            
            case .routeAction(.editStation(.delegate(.stationEdited))):
                // TODO: If the station edited was the currently playing station then reload it.
                state.route = nil
                return Effect(value: .onAppear)
                
            case .routeAction(.editDirectory(.delegate(.directoryEdited))):
                state.route = nil
                return Effect(value: .onAppear)

            case .routeAction(.createDirectory(.delegate(.directoryAdded))):
                state.route = nil
                return Effect(value: .onAppear)

            case let .routeAction(.subDirectory(.delegate(.selected(station)))):
                // Propogate selected station
                return Effect(value: .delegate(.selected(station)))
                
            case .routeAction:
                return .none
                
            case .station:
                return .none
            
            case let .directory(id, .delegate(.edit)):
                guard let dir = state.directories[id: id]?.directory else {
                    return .none
                }

                state.route = .editDirectory(.init(editedDirectory: dir))
                return .none

            case let .directory(id, .delegate(.delete)):
                return .task { [state] in
                    // TODO: Deal with error
                    // TODO: Recursively check folders if they contain the station currently playing,
                    // If yes, stop playing first. (This doesn't have to be recursion. Could be done based on the file path)
                    try await state.directories[id: id]?.directory.remove()
                    
                    return .onAppear
                }
                
            case let .directory(id, .delegate(.selected)):
                guard let dir = state.directories[id: id] else {
                    return .none
                }
                state.route = .subDirectory(.init(rootDirectory: dir.directory))
                return .none
            }
        }
    }
    
    private var createStation: some ReducerProtocol<Stations.State.Route, Stations.Action.RouteAction> {
        Scope(state: /State.Route.createStation, action: /Action.RouteAction.createStation) {
            CreateStation()
        }
    }
    private var editStation: some ReducerProtocol<Stations.State.Route, Stations.Action.RouteAction> {
        Scope(state: /State.Route.editStation, action: /Action.RouteAction.editStation) {
            EditStation()
        }
    }
    private var createDirectory: some ReducerProtocol<Stations.State.Route, Stations.Action.RouteAction> {
        Scope(state: /State.Route.createDirectory, action: /Action.RouteAction.createDirectory) {
            CreateDirectory()
        }
    }
    private var editDirectory: some ReducerProtocol<Stations.State.Route, Stations.Action.RouteAction> {
        Scope(state: /State.Route.editDirectory, action: /Action.RouteAction.editDirectory) {
            EditDirectory()
        }
    }
    private var subDirectory: some ReducerProtocol<Stations.State.Route, Stations.Action.RouteAction> {
        Scope(state: /State.Route.subDirectory, action: /Action.RouteAction.subDirectory) {
            Stations()
        }
    }
    
    var body: some ReducerProtocol<State, Action> {
        core
        .forEach(\.stations, action: /Action.station) {
            StationRow()
        }
        .forEach(\.directories, action: /Action.directory) {
            DirectoryRow()
        }
        .ifLet(\.route, action: /Action.routeAction) {
            createStation
            editStation
            createDirectory
            editDirectory
            subDirectory
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
                ForEachStore(
                    store.scope(
                        state: \.stations,
                        action: Stations.Action.station(id:action:))
                ) { store in
                    StationRowView(store: store)
                }
                
                ForEachStore(
                    store.scope(
                        state: \.directories,
                        action: Stations.Action.directory(id:action:)
                    )
                ) { store in
                    DirectoryRowView(store: store)
                }
                HStack {
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
                            Image(systemName: "radio.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                    
                    Button {
                        viewStore.send(.showCreateDirectory)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                                .foregroundColor(.green)
                            Image(systemName: "folder.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(viewStore.state.rootDirectory.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewStore.send(.onAppear)
        }
        .navigationDestination(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Stations.Action.setRoute
            ),
            case: /Stations.State.Route.subDirectory,
            destination: { $value in
                let store = store.scope(
                    state: { _ in $value.wrappedValue },
                    action: { Stations.Action.routeAction(.subDirectory($0)) }
                )
                StationsView(store: store)
            }
        )
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
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Stations.Action.setRoute
            ),
            case: /Stations.State.Route.editDirectory
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Stations.Action.routeAction(.editDirectory($0)) }
            )
            EditDirectoryView(store: store)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Stations.Action.setRoute
            ),
            case: /Stations.State.Route.createDirectory
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Stations.Action.routeAction(.createDirectory($0)) }
            )
            CreateDirectoryView(store: store)
                .interactiveDismissDisabled()
        }
    }
}
