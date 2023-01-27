import SwiftUI
import ComposableArchitecture

struct EditStation: ReducerProtocol {
    struct State: Equatable {
        let editedStation: Stream
        let containingDirectory: Directory
        var title: String = ""
        var url: String = ""
        var imageURL: String = ""
        
        init(
            editedStation: Stream,
            containingDirectory: Directory
        ) {
            self.editedStation = editedStation
            self.containingDirectory = containingDirectory
            self.title = editedStation.title
            self.url = editedStation.url.absoluteString
            self.imageURL = editedStation.imageURL?.absoluteString ?? ""
        }
    }
    
    enum Action: Equatable {
        case setTitle(String)
        case setURL(String)
        case setImageURL(String)
        case addStation
        
        enum Delegate {
            case stationEdited
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
                        id: state.editedStation.id,
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
                    
                    return .delegate(.stationEdited)
                }
                
            case .delegate:
                return .none
            }
        }
    }
}

struct EditStationView: View {
    let store: StoreOf<EditStation>
    @ObservedObject var viewStore: ViewStoreOf<EditStation>
    
    init(store: StoreOf<EditStation>) {
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
                        send: EditStation.Action.setTitle
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                TextField(
                    "URL",
                    text: viewStore.binding(
                        get: \.url,
                        send: EditStation.Action.setURL
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                TextField(
                    "Image URL",
                    text: viewStore.binding(
                        get: \.imageURL,
                        send: EditStation.Action.setImageURL
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                    
                Button {
                    viewStore.send(.addStation)
                } label: {
                    Text("Update")
                        .foregroundColor(.indigo)
                }.disabled(viewStore.url.isEmpty || viewStore.title.isEmpty)
            }
        }
    }
}

