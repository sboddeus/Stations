
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
        case addStation
        
        enum Delegate {
            case stationAdded
        }
        case delegate(Delegate)
    }
    
    @Dependency(\.stationMaster) var stationMaster
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setTitle(title):
                state.title = title
                return .none
                
            case let .setURL(url):
                state.url = url
                return .none
                
            case .addStation:
                return .task { [state] in
                    await stationMaster.add(
                        station: .init(
                            id: state.title,
                            title: state.title,
                            description: "",
                            url: URL(string: state.url)!
                        )
                    )
                    
                    return .delegate(.stationAdded)
                }
                
            case .delegate:
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
            Button {
                viewStore.send(.addStation)
            } label: {
                Text("Create")
            }.disabled(viewStore.url.isEmpty || viewStore.title.isEmpty)
        }
    }
}

