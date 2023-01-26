
import SwiftUI
import ComposableArchitecture

struct Help: ReducerProtocol {
    struct State: Equatable {
        
    }
    
    enum Action: Equatable {
        
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}

struct HelpView: View {
    let store: StoreOf<Help>
    @ObservedObject var viewStore: ViewStoreOf<Help>
    
    init(store: StoreOf<Help>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        Text("Get good at technology")
    }
}

