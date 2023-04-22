
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
            case createDirectory(CreateDirectory.State)
            case editDirectory(EditDirectory.State)
            case subDirectory(Streams.State)
            case editMenu(EditMenu.State)
            case clipBoard(ClipBoardReducer.State)
        }
        var route: Route?

        var alert: AlertState<Action>?
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
        case showPasteError
        case showClipboardCopyError(String)
        case alertDismissed

        // Child Actions
        indirect enum RouteAction: Equatable {
            case createStation(CreateStream.Action)
            case subDirectory(Streams.Action)
            case editDirectory(EditDirectory.Action)
            case createDirectory(CreateDirectory.Action)
            case editMenu(EditMenu.Action)
            case clipBoard(ClipBoardReducer.Action)
        }
        case routeAction(RouteAction)
        
        case station(id: StreamRow.State.ID, action: StreamRow.Action)
        case directory(id: DirectoryRow.State.ID, action: DirectoryRow.Action)
    }
    
    @Dependency(\.player) var player
    @Dependency(\.clipBoard) var clipBoard
    
    private var core: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .alertDismissed:
                state.alert = nil
                return .none

            case .showEditOptions:
                state.route = .editMenu(.init())
                return .none
                
            case let .setRoute(route):
                state.route = route
                return .none

            case .showPasteError:
                state.route = nil
                state.alert = .init(
                    title: .init("Could not paste item"),
                    message: .init("Ensure the folder has a unique name and that device storage is not full."),
                    dismissButton: .default(
                        .init("Ok"),
                        action: .send(.alertDismissed)
                    )
                )
                return .none

            case let .showClipboardCopyError(message):
                state.route = nil
                state.alert = .init(
                    title: .init("Could not copy item"),
                    message: .init(verbatim: message),
                    dismissButton: .default(
                        .init("Ok"),
                        action: .send(.alertDismissed)
                    )
                )
                return .none
             
                // MARK: - Station actions
            case let .station(id, action: .delegate(.delete)):
                return .task { [state] in
                    // Stop playing the station if it is playing
                    if player.currentItem?.id == id {
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
                
            case let .station(id, action: .delegate(.edit)):
                if let station = state.stations[id: id]?.station {
                    state.route = .createStation(
                        .init(
                            containingDirectory: state.rootDirectory,
                            mode: .edit(station)
                        )
                    )
                }
                return .none
                
            case let .station(id, action: .delegate(.copy)):
                if let station = state.stations[id: id]?.station {
                    return .task {
                        await clipBoard.add(stream: station)
                        return .station(id: id, action: .delegate(.delete))
                    }
                }
                return .none

            case let .station(id, action: .delegate(.duplicate)):
                if let station = state.stations[id: id]?.station {
                    return .task { [state] in
                        let newStream = Stream(
                            id: .init(),
                            title: station.title + " (copy)",
                            description: station.description,
                            imageURL: station.imageURL,
                            url: station.url
                        )

                        let file = try await state.rootDirectory.file(
                            name: newStream.id
                        )
                        try await file.save(newStream)

                        return .onAppear
                    }
                }
                return .none
                
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
                        containingDirectory: state.rootDirectory,
                        mode: .create
                    )
                )
                return .none

            case let .routeAction(.clipBoard(.delegate(.selected(content)))):
                state.route = nil
                return .run { [state] send in
                    do {
                        switch content {
                        case let .directory(copiedDir):
                            _ = try await copiedDir.move(into: state.rootDirectory)

                        case let .stream(copiedStream):
                            let file = try await state.rootDirectory.file(
                                name: copiedStream.id
                            )

                            try await file.save(copiedStream)
                        }

                        await clipBoard.remove(content: content)

                        await send(.onAppear)
                    } catch {
                        await send(.setRoute(nil))
                        await send(.showPasteError)
                    }
                }

            case .routeAction(.editMenu(.delegate(.paste))):
                return .run { [state] send in

                    let content = await clipBoard.content()
                    if content.count > 1 {
                        await send(.setRoute(.clipBoard(.init())))
                    } else if let content = content.first {
                        do {
                            switch content {
                            case let .directory(copiedDir):
                                _ = try await copiedDir.move(into: state.rootDirectory)

                            case let .stream(copiedStream):
                                let file = try await state.rootDirectory.file(
                                    name: copiedStream.id
                                )

                                try await file.save(copiedStream)
                            }

                            await clipBoard.remove(content: content)

                            await send(.setRoute(nil))
                            await send(.onAppear)
                        } catch {
                            await send(.setRoute(nil))
                            await send(.showPasteError)
                        }
                    }
                }
                
            case .routeAction(.createStation(.delegate(.stationAdded))):
                state.route = nil
                return .task { .onAppear }
                
            case .routeAction(.editDirectory(.delegate(.directoryEdited))):
                state.route = nil
                return .task { .onAppear }

            case .routeAction(.createDirectory(.delegate(.directoryAdded))):
                state.route = nil
                return .task { .onAppear }

            case let .routeAction(.subDirectory(.delegate(.selected(station)))):
                // Propogate selected station
                return .task { .delegate(.selected(station)) }
                
            case .routeAction:
                return .none
                
            case .station:
                return .none
            
                // MARK: Directory Row Actions
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
                
            case let .directory(id, .delegate(.copy)):
                guard let dir = state.directories[id: id] else {
                    return .none
                }
                                
                return .task {
                    // TODO: Recursively check folders if they contain the station currently playing,
                    // If yes, stop playing first. (This doesn't have to be recursion. Could be done based on the file path)
                    do {
                        try await clipBoard.add(directory: dir.directory)

                        return .onAppear
                    } catch {
                        return .showClipboardCopyError(error.localizedDescription)
                    }
                }
                
            case let .directory(id, .delegate(.selected)):
                guard let dir = state.directories[id: id] else {
                    return .none
                }
                state.route = .subDirectory(.init(rootDirectory: dir.directory))
                return .none

            case let .directory(id, .delegate(.duplicate)):
                guard let dir = state.directories[id: id] else {
                    return .none
                }
                return .task {
                    _ = try await dir.directory.duplicate()
                    return .onAppear
                }
            }
        }
    }
    
    private var createStation: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.createStation, action: /Action.RouteAction.createStation) {
            CreateStream()
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
    private var clipBoardReducer: some ReducerProtocol<Streams.State.Route, Streams.Action.RouteAction> {
        Scope(state: /State.Route.clipBoard, action: /Action.RouteAction.clipBoard) {
            ClipBoardReducer()
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
            createDirectory
            editDirectory
            subDirectory
            editMenu
            clipBoardReducer
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
        .alert(
            self.store.scope(state: \.alert),
            dismiss: Streams.Action.alertDismissed
        )
        .navigationDestination(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.subDirectory,
            destination: { $value in
                let store = store.scope(
                    state: { $0.route.flatMap(/Streams.State.Route.subDirectory) ?? value },
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
                state: { $0.route.flatMap(/Streams.State.Route.editMenu) ?? value },
                action: { Streams.Action.routeAction(.editMenu($0)) }
            )
            EditMenuView(store: store)
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.clipBoard
        ) { $value in
            let store = store.scope(
                state: { $0.route.flatMap(/Streams.State.Route.clipBoard) ?? value },
                action: { Streams.Action.routeAction(.clipBoard($0)) }
            )
            ClipBoardView(store: store)
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Streams.Action.setRoute
            ),
            case: /Streams.State.Route.createStation
        ) { $value in
            let store = store.scope(
                state: { $0.route.flatMap(/Streams.State.Route.createStation) ?? value },
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
            case: /Streams.State.Route.editDirectory
        ) { $value in
            let store = store.scope(
                state: { $0.route.flatMap(/Streams.State.Route.editDirectory) ?? value },
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
                state: { $0.route.flatMap(/Streams.State.Route.createDirectory) ?? value },
                action: { Streams.Action.routeAction(.createDirectory($0)) }
            )
            CreateDirectoryView(store: store)
                .interactiveDismissDisabled()
        }
    }
}
