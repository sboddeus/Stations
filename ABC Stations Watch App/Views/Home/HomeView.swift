
import SwiftUI
import ComposableArchitecture
import SwiftUINavigation
import AVFoundation
import WatchKit
import WatchDEBUG

struct Home: ReducerProtocol {
    struct State: Equatable {
        enum Route: Equatable {
            case debug
            case menu(Menu.State)
            case stations(Stations.State)
        }
        var route: Route?
        
        var nowPlaying = NowPlaying.State()
        var recentlyPlayed = RecentlyPlayed.State()
    }
    
    enum Action: Equatable {
        case setRoute(State.Route?)
        case nowPlaying(NowPlaying.Action)
        case recentlyPlayed(RecentlyPlayed.Action)
        case showMenu
        case showHome
        case showStations
        
        enum RouteAction: Equatable {
            case menu(Menu.Action)
            case stations(Stations.Action)
        }
        case routeAction(RouteAction)
    }
        
    @Dependency(\.stationMaster) var stationMaster
    
    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.nowPlaying, action: /Action.nowPlaying) {
            NowPlaying()
        }
        Scope(state: \.recentlyPlayed, action: /Action.recentlyPlayed) {
            RecentlyPlayed()
        }
        Reduce { state, action in
            switch action {
            case .showStations:
                return .task {
                    await stationMaster.constructInitialSystemIfNeeded()
                    let rootDir = await stationMaster.rootDirectory
                    return .setRoute(.stations(Stations.State(rootDirectory: rootDir)))
                }
                
            case let .setRoute(route):
                state.route = route
                return .none
            
            case .showMenu:
                state.route = .menu(.init())
                return .none
                
            case .routeAction(.menu(.delegate(.tappedDebugMenu))):
                state.route = .debug
                return .none
                
            case .showHome:
                state.route = nil
                return .none
                
            default:
                return .none
            }
        }
        .ifLet(\.route, action: /Action.routeAction) {
            Scope(state: /State.Route.menu, action: /Action.RouteAction.menu) {
                Menu()
            }
            Scope(state: /State.Route.stations, action: /Action.RouteAction.stations) {
                Stations()
            }
        }
    }
}

struct HomeView: View {
    let store: StoreOf<Home>
    @ObservedObject var viewStore: ViewStoreOf<Home>
    
    init(store: StoreOf<Home>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                ScrollView {
                    VStack {
                        NowPlayingView(
                            store: store.scope(
                                state: \.nowPlaying,
                                action: { Home.Action.nowPlaying($0) }
                            )
                        )
                    }
                    Button {
                        viewStore.send(.showStations)
                    } label: {
                        Text("Stations")
                    }
                    Button {
                        viewStore.send(.showMenu)
                    } label: {
                        Text("Options")
                    }
                    RecentlyPlayedView(
                        store: store.scope(
                            state: \.recentlyPlayed,
                            action: { Home.Action.recentlyPlayed($0) }
                        )
                    )
                }
                .navigationDestination(
                    unwrapping: viewStore.binding(
                        get: \.route,
                        send: Home.Action.setRoute
                    ),
                    case: /Home.State.Route.stations,
                    destination: { $value in
                        let store = store.scope(
                            state: { _ in $value.wrappedValue },
                            action: { Home.Action.routeAction(.stations($0)) }
                        )
                        StationsView(store: store)
                    }
                )
            }
            switch viewStore.route {
            case .stations:
                Button {
                    viewStore.send(.showHome)
                } label: {
                    Image(systemName: "house")
                        .foregroundColor(.indigo)
                }
                .backgroundStyle(.indigo)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .padding(.trailing, 5)
                .offset(y: 10)
            default:
                EmptyView()
            }
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Home.Action.setRoute
            ),
            case: /Home.State.Route.menu
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Home.Action.routeAction(.menu($0)) }
            )
            MenuView(store: store)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { viewStore.send(.setRoute(nil)) }) {
                           Text("Close")
                        }
                    }
                }
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Home.Action.setRoute
            ),
            case: /Home.State.Route.debug
        ) { _ in
            DEBUG()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { viewStore.send(.setRoute(nil)) }) {
                           Text("Close")
                        }
                    }
                }
        }
    }
}

