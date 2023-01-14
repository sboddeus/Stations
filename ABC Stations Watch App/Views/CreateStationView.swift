
import SwiftUI
import ComposableArchitecture

struct CreateStation: ReducerProtocol {
    struct State: Equatable {
        var title: String = ""
        var url: String = ""
    }
    
    enum Action: Equatable {
        case setTitle(String)
        case setURL(String)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setTitle(title):
                state.title = title
                return .none
                
            case let .setURL(url):
                state.url = url
                return .none
            }
        }
    }
}

struct CreateStationView: View {
    let store: StoreOf<CreateStation>
    @ObservedObject var viewStore: ViewStoreOf<CreateStation>
    
    init(store: StoreOf<CreateStation>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        VStack {
            TextField("Name", text: viewStore.binding(get: \.title, send: CreateStation.Action.setTitle))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            TextField("URL", text: viewStore.binding(get: \.url, send: CreateStation.Action.setURL))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
    }
}

