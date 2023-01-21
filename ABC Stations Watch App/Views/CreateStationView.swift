
import SwiftUI
import ComposableArchitecture

struct CreateStation: ReducerProtocol {
    struct State: Equatable {
        var title: String = ""
        var url: String = ""
        var imageURL: String = ""
    }
    
    enum Action: Equatable {
        case setTitle(String)
        case setURL(String)
        case setImageURL(String)
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
                
            case let .setImageURL(url):
                state.imageURL = url
                return .none
                
            case .addStation:
                return .task { [state] in
                    
                    await stationMaster.add(
                        station: .init(
                            id: state.title,
                            title: state.title,
                            description: "",
                            // TODO: These URLs have to be checked properly
                            imageURL: URL(string: state.imageURL),
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
        ScrollView {
            VStack {
                TextField(
                    "Name",
                    text: viewStore.binding(
                        get: \.title,
                        send: CreateStation.Action.setTitle
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                TextField(
                    "URL",
                    text: viewStore.binding(
                        get: \.url,
                        send: CreateStation.Action.setURL
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                TextField(
                    "Image URL",
                    text: viewStore.binding(
                        get: \.imageURL,
                        send: CreateStation.Action.setImageURL
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                Button {
                    viewStore.send(.addStation)
                } label: {
                    Text("Create")
                        .foregroundColor(.indigo)
                }.disabled(viewStore.url.isEmpty || viewStore.title.isEmpty)
            }
        }
    }
}

