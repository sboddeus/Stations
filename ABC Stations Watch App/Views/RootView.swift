
import SwiftUI
import ComposableArchitecture
import AVFoundation
import WatchKit
import WatchDEBUG

struct Root: ReducerProtocol {
    struct State: Equatable {
        enum Route: Int, Equatable {
            case debug
            case stations
            case nowPlaying
        }
        var route: Route
        var stations: Stations.State
    }
    
    enum Action: Equatable {
        case setRoute(State.Route)
        case stations(Stations.Action)
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
            default:
                return .none
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
        TabView(
            selection: viewStore.binding(
                get: \.route,
                send: Root.Action.setRoute
            )
        ) {
            DEBUG().tag(Root.State.Route.debug)

            StationsView(
                store: self.store.scope(
                    state: \.stations,
                    action: Root.Action.stations
                )
            ).tag(Root.State.Route.stations)

            NowPlayingView().tag(Root.State.Route.nowPlaying)

        }.tabViewStyle(.page)
    }
}

