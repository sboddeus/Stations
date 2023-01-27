
import SwiftUI
import ComposableArchitecture
import AVFAudio
import SwiftUINavigation
import SDWebImageSwiftUI

struct Streams: ReducerProtocol {
    struct State: Equatable {
        var rootDirectory: Directory
        
        init(rootDirectory: Directory) {
            self.rootDirectory = rootDirectory
        }
        
        var isLoading = true
        var stations: IdentifiedArrayOf<StreamRow.State> = []
        var directories: IdentifiedArrayOf<DirectoryRow.State> = []
        
        indirect enum Route: Equatable {
            case createStation(CreateStream.State)
            case editStation(EditStream.State)
            case createDirectory(CreateDirectory.State)
            case editDirectory(EditDirectory.State)
            case subDirectory(Streams.State)
            case editMenu(EditMenu.State)
        }
        var route: Route?
    }
    
    indirect enum Action: Equatable {
        enum Delegate: Equatable {
            case selected(Stream)
        }
        case delegate(Delegate)

        // Internal actions
        case setRoute(State.Route?)
        case showEditOptions
        case onAppear
        case loadedStations([Stream])
        case loadedSubDirectories([Directory])

        // Child Actions
        indirect enum RouteAction: Equatable {
            case createStation(CreateStream.Action)
            case editStation(EditStream.Action)
            case subDirectory(Streams.Action)
            case editDirectory(EditDirectory.Action)
            case createDirectory(CreateDirectory.Action)
            case editMenu(EditMenu.Action)
        }
        case routeAction(RouteAction)
        
        case station(id: StreamRow.State.ID, action: StreamRow.Action)
        case directory(id: DirectoryRow.State.ID, action: DirectoryRow.Action)
    }
    
    @Dependency(\.player) var player
    
    private var core: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .showEditOptions:
                state.route = .editMenu(.init())
                return .none
                
            case let .setRoute(route):
                state.route = route
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
                    return .run { send in
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
                } else {
                    return .none
                }
                
            case .delegate:
                return .none
                
            case .onAppear:
                struct OnAppearID {}
                return .run { [directory = state.rootDirectory] send in
                    let stations = await directory.getAllStations().sorted(by: { $0.title < $1.title })
                    
                    await send(.loadedStations(stations))
                    
                    let directories = (try? await directory.retrieveAllSubDirectories().sorted(by: { $0.name < $1.name })) ?? []
                    
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
        
            case .routeAction(.editMenu(.delegate(.addFolder))):
                state.route = .createDirectory(
                    .init(
                        containingDirectory: state.rootDirectory
                    )
                )
                return .none
                
            case .routeAction(.editMenu(.delegate(.addStation))):
                state.route = .createStation(
                    .init(
                        containingDirectory: state.rootDirectory
                    )
                )
                return .none
                
            case .routeAction(.createStation(.delegate(.stationAdded))):
                state.route = nil
                return EffectTask(value: .onAppear)
            
            case .routeAction(.editStation(.delegate(.stationEdited))):
                // TODO: If the station edited was the currently playing station then reload it.
                state.route = nil
                return EffectTask(value: .onAppear)
                
            case .routeAction(.editDirectory(.delegate(.directoryEdited))):
                state.route = nil
                return EffectTask(value: .onAppear)

            case .routeAction(.createDirectory(.delegate(.directoryAdded))):
                state.route = nil
                return EffectTask(value: .onAppear)

            case let .routeAction(.subDirectory(.delegate(.selected(station)))):
                // Propogate selected station
                return EffectTask(value: .delegate(.selected(station)))
                
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
    
    private var createStation: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.createStation, action: /Action.RouteAction.createStation) {
            CreateStream()
        }
    }
    private var editStation: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.editStation, action: /Action.RouteAction.editStation) {
            EditStream()
        }
    }
    private var createDirectory: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.createDirectory, action: /Action.RouteAction.createDirectory) {
            CreateDirectory()
        }
    }
    private var editDirectory: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.editDirectory, action: /Action.RouteAction.editDirectory) {
            EditDirectory()
        }
    }
    private var subDirectory: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.subDirectory, action: /Action.RouteAction.subDirectory) {
            Streams()
        }
    }
    private var editMenu: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.editMenu, action: /Action.RouteAction.editMenu) {
            EditMenu()
        }
    }
    
    var body: some ReducerProtocol<State, Action> {
        core
        .forEach(\.stations, action: /Action.station) {
            StreamRow()
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

struct StreamsView: View {
    let store: StoreOf<Streams>
    @ObservedObject var viewStore: ViewStoreOf<Streams>
    
    init(store: StoreOf<Streams>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        List {
            ForEachStore(
                store.scope(
                    state: \.stations,
                    action: Streams.Action.station(id:action:))
            ) { store in
                StreamRowView(store: store)
            }
            
            ForEachStore(
                store.scope(
                    state: \.directories,
                    action: Streams.Action.directory(id:action:)
                )
            ) { store in
                DirectoryRowView(store: store)
            }
            Section {
                Button {
                    viewStore.send(.showEditOptions)
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
        }
        .navigationTitle(viewStore.state.rootDirectory.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewStore.send(.onAppear)
        }
        .navigationDestination(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.subDirectory,
            destination: { $value in
                let store = store.scope(
                    state: { _ in $value.wrappedValue },
                    action: { Streams.Action.routeAction(.subDirectory($0)) }
                )
                StreamsView(store: store)
            }
        )
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.editMenu
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Streams.Action.routeAction(.editMenu($0)) }
            )
            EditMenuView(store: store)
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.createStation
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Streams.Action.routeAction(.createStation($0)) }
            )
            CreateStreamView(store: store)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.editStation
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Streams.Action.routeAction(.editStation($0)) }
            )
            EditStreamView(store: store)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.editDirectory
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Streams.Action.routeAction(.editDirectory($0)) }
            )
            EditDirectoryView(store: store)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.createDirectory
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Streams.Action.routeAction(.createDirectory($0)) }
            )
            CreateDirectoryView(store: store)
                .interactiveDismissDisabled()
        }
    }
}
