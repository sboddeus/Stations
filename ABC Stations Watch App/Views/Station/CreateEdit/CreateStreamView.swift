
import SwiftUI
import ComposableArchitecture

struct CreateStream: ReducerProtocol {
    struct State: Equatable {
        let containingDirectory: Directory
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
                    
                    let station = Stream(
                       id: UUID(),
                       title: state.title,
                       description: "",
                       // TODO: These URLs have to be checked properly
                       imageURL: URL(string: state.imageURL),
                       url: URL(string: state.url)!
                    )
                   
                    let file = try await state.containingDirectory.file(
                        name: station.id.uuidString
                    )
                    try await file.save(station)
                    
                    return .delegate(.stationAdded)
                }
                
            case .delegate:
                return .none
            }
        }
    }
}

struct CreateStreamView: View {
    let store: StoreOf<CreateStream>
    @ObservedObject var viewStore: ViewStoreOf<CreateStream>
    
    init(store: StoreOf<CreateStream>) {
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
                        send: CreateStream.Action.setTitle
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                TextField(
                    "URL",
                    text: viewStore.binding(
                        get: \.url,
                        send: CreateStream.Action.setURL
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                TextField(
                    "Image URL",
                    text: viewStore.binding(
                        get: \.imageURL,
                        send: CreateStream.Action.setImageURL
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

