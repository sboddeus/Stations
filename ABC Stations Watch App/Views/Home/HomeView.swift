
import SwiftUI
import ComposableArchitecture

struct Home: ReducerProtocol {
    struct State: Equatable {
        enum Route: Equatable {
            
        }
        
        var nowPlaying = NowPlaying.State()
    }
    
    enum Action: Equatable {
        case nowPlaying(NowPlaying.Action)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.nowPlaying, action: /Action.nowPlaying) {
            NowPlaying()
        }
        Reduce { state, action in
            return .none
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
        ScrollView {
            NowPlayingView(
                store: store.scope(
                    state: \.nowPlaying,
                    action: Home.Action.nowPlaying
                )
            )
        }
    }
}
