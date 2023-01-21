
import SwiftUI
import ComposableArchitecture
import SwiftUINavigation
import AVFoundation
import WatchKit
import WatchDEBUG

struct Root: ReducerProtocol {
    struct State: Equatable {
        enum Route: Equatable {
            case debug
            case nowPlaying
            case menu(Menu.State)
        }
        var route: Route?
        var stations: Stations.State
    }
    
    enum Action: Equatable {
        case setRoute(State.Route?)
        case stations(Stations.Action)
        case showMenu
        
        enum RouteAction: Equatable {
            case menu(Menu.Action)
        }
        case routeAction(RouteAction)
    }
        
    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.stations, action: /Action.stations) {
            Stations()
        }
        Reduce { state, action in
            switch action {
            case let .setRoute(route):
                state.route = route
                return .none
            
            case .stations(.delegate(.selected)):
                state.route = .nowPlaying
                return .none
            
            case .showMenu:
                state.route = .menu(.init())
                return .none
                
            case .routeAction(.menu(.delegate(.tappedDebugMenu))):
                state.route = .debug
                return .none
                
            case .routeAction(.menu(.delegate(.tappedNowPlaying))):
                state.route = .nowPlaying
                return .none
                
            default:
                return .none
            }
        }.ifLet(\.route, action: /Action.routeAction) {
            Scope(state: /State.Route.menu, action: /Action.RouteAction.menu) {
                Menu()
            }
        }
    }
}

struct RootView: View {
    let store: StoreOf<Root>
    @ObservedObject var viewStore: ViewStoreOf<Root>
    
    init(store: StoreOf<Root>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                StationsView(
                    store: self.store.scope(
                        state: \.stations,
                        action: Root.Action.stations
                    )
                )
                .navigationTitle("Stations")
                .navigationBarTitleDisplayMode(.inline)
            }
            
            Button {
                viewStore.send(.showMenu)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.indigo)
            }
            .backgroundStyle(.indigo)
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            .padding(.trailing, 5)
            .offset(y: 10)
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Root.Action.setRoute
            ),
            case: /Root.State.Route.menu
        ) { $value in
            let store = store.scope(
                state: { _ in $value.wrappedValue },
                action: { Root.Action.routeAction(.menu($0)) }
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
                send: Root.Action.setRoute
            ),
            case: /Root.State.Route.nowPlaying
        ) { _ in
            NowPlayingView()
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
                send: Root.Action.setRoute
            ),
            case: /Root.State.Route.debug
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

