
import SwiftUI
import ComposableArchitecture
import SwiftUINavigation
import AVFoundation
import WatchKit
import WatchDEBUG

struct Home: ReducerProtocol {
    struct State: Equatable {
        enum Route: Equatable {
            case menu(Menu.State)
            case stations(Stream.State)
            case help(Help.State)
        }
        var route: Route?
        
        var nowPlaying = NowPlaying.State()
        var recentlyPlayed = RecentlyPlayed.State()
        
        var showFullScreenNowPlaying = false
        
        var alert: AlertState<Action>?
    }
    
    enum Action: Equatable {
        // Child actions
        case nowPlaying(NowPlaying.Action)
        case recentlyPlayed(RecentlyPlayed.Action)
        
        // Internal
        case playerBinding
        
        case showMenu
        case showHome
        case showNowPlaying(Bool)
        case showHelp
        case showStations
        case showAssetLoadingAlert
        
        case alertDismissed
        
        case setRoute(State.Route?)
        
        // Routed actions
        enum RouteAction: Equatable {
            case menu(Menu.Action)
            case stations(Stream.Action)
            case help(Help.Action)
        }
        case routeAction(RouteAction)
    }
        
    @Dependency(\.player) var player
    @Dependency(\.streamMaster) var stationMaster
    
    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.nowPlaying, action: /Action.nowPlaying) {
            NowPlaying()
        }
        Scope(state: \.recentlyPlayed, action: /Action.recentlyPlayed) {
            RecentlyPlayed()
        }
        Reduce { state, action in
            switch action {
            case .playerBinding:
                return .run { send in
                    let values = player.playerErrorState.compactMap { $0 }.values
                    for await _ in values {
                        try Task.checkCancellation()
                        await send(.showAssetLoadingAlert)
                    }
                }
            case .showStations:
                return .task {
                    await stationMaster.constructInitialSystemIfNeeded()
                    let rootDir = await stationMaster.rootDirectory
                    return .setRoute(.stations(Stream.State(rootDirectory: rootDir)))
                }
                
            case let .setRoute(route):
                state.route = route
                return .none
            
            case .showMenu:
                state.route = .menu(.init())
                return .none
                
            case .showHome:
                state.route = nil
                return .none
                
            case .showHelp:
                state.route = .help(.init())
                return .none
                
            case let .showNowPlaying(show):
                state.showFullScreenNowPlaying = show
                return .none
                
            case .alertDismissed:
                state.alert = nil
                return .none
            
            case .showAssetLoadingAlert:
                state.alert = .init(
                    title: .init("Could not load stream"),
                    message: .init("Ensure the stream url is correct and is a HLS stream. (They ususally end in .m3u8). See help for more details"),
                    dismissButton: .default(
                        .init("Ok"),
                        action: .send(.alertDismissed)
                    )
                )
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
                Stream()
            }
            Scope(state: /State.Route.help, action: /Action.RouteAction.help) {
                Help()
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
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Now Playing")
                                .font(.title3)
                                .foregroundColor(LeincastColors.brand.color)
                            Divider()
                            NowPlayingView(
                                store: store.scope(
                                    state: \.nowPlaying,
                                    action: { Home.Action.nowPlaying($0) }
                                )
                            ).environment(\.presentationContext, .embedded)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Streams")
                                .font(.title3)
                                .foregroundColor(LeincastColors.brand.color)
                            Divider()
                            Button {
                                viewStore.send(.showStations)
                            } label: {
                                Text("Your Streams")
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recently Played")
                                .font(.title3)
                                .foregroundColor(LeincastColors.brand.color)
                            Divider()
                            RecentlyPlayedView(
                                store: store.scope(
                                    state: \.recentlyPlayed,
                                    action: { Home.Action.recentlyPlayed($0) }
                                )
                            )
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Help and Settings")
                                .font(.title3)
                                .foregroundColor(LeincastColors.brand.color)
                            Divider()
                            Button {
                                viewStore.send(.showMenu)
                            } label: {
                                Text("Settings")
                            }
                            Button {
                                viewStore.send(.showHelp)
                            } label: {
                                Text("Help")
                            }
                        }
                    }
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
                        SteamsView(store: store)
                    }
                )
                .navigationDestination(
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
                }
                .navigationDestination(
                    unwrapping: viewStore.binding(
                        get: \.route,
                        send: Home.Action.setRoute
                    ),
                    case: /Home.State.Route.help
                ) { $value in
                    let store = store.scope(
                        state: { _ in $value.wrappedValue },
                        action: { Home.Action.routeAction(.help($0)) }
                    )
                    HelpView(store: store)
                }
            }
            switch viewStore.route {
            case .stations, .help:
                Button {
                    viewStore.send(.showNowPlaying(true))
                } label: {
                    Image(systemName: "waveform.path")
                        .foregroundColor(LeincastColors.brand.color)
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
        .task {
            await viewStore.send(.playerBinding).finish()
        }
        .alert(
            self.store.scope(
                state: \.alert),
            dismiss: Home.Action.alertDismissed
        )
        .fullScreenCover(isPresented: viewStore.binding(
            get: \.showFullScreenNowPlaying,
            send: Home.Action.showNowPlaying
        )) {
            VStack(alignment: .leading) {
                NowPlayingView(
                    store: store.scope(
                        state: \.nowPlaying,
                        action: { Home.Action.nowPlaying($0) }
                    )
                )
                .environment(\.presentationContext, .fullScreen)
            }.toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { viewStore.send(.showNowPlaying(false)) }) {
                       Text("Close")
                    }
                }
            }
        }
    }
}

