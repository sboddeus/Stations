
import SwiftUI
import ComposableArchitecture

struct CreateStream: Reducer {
    struct State: Equatable {
        let containingDirectory: Directory
        var title: String = ""
        var url: String = ""
        var description: String = ""
        var imageURL: String = ""
        @PresentationState var alert: AlertState<Never>?

        enum Mode: Equatable {
            case edit(Stream)
            case create
        }
        
        let mode: Mode
        
        init(containingDirectory: Directory, mode: Mode) {
            self.mode = mode
            self.containingDirectory = containingDirectory
            switch mode {
            case let .edit(stream):
                title = stream.title
                url = stream.url.absoluteString
                description = stream.description
                imageURL = stream.imageURL?.absoluteString ?? ""
            case .create:
                title = ""
                url = ""
                description = ""
                imageURL = ""
            }
            alert = nil
        }
    }
    
    enum Action: Equatable {
        
        // Internal
        case setTitle(String)
        case setURL(String)
        case setDescription(String)
        case setImageURL(String)
        case addStation
        case showInvalidImageURLAlert
        case showInvalidContentURLAlert
        case showEmptyTitleAlert
        case alertDismissed
        
        // Delegate
        enum Delegate {
            case stationAdded
        }
        case delegate(Delegate)
    }
        
    var body: some Reducer<State, Action> {
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
                
            case let .setDescription(desc):
                state.description = desc
                return .none
                
            case .showInvalidImageURLAlert:
                state.alert = .init(
                    title: .init("Invalid Image URL"),
                    message: .init("Ensure the image url is a valid URL and is a file of type PNG or JPEG"),
                    dismissButton: .default(
                        .init("Ok")                    )
                )
                return .none
                
            case .showInvalidContentURLAlert:
                state.alert = .init(
                    title: .init("Invalid stream URL"),
                    message: .init("Ensure the stream url is a valid URL and is a HLS stream. Which usually ends in .m3u8"),
                    dismissButton: .default(
                        .init("Ok")                    )
                )
                return .none
                
            case .showEmptyTitleAlert:
                state.alert = .init(
                    title: .init("Empty Title"),
                    message: .init("Ensure your stream has a name 😬"),
                    dismissButton: .default(
                        .init("Ok")                    )
                )
                return .none
                
            case .alertDismissed:
                state.alert = nil
                return .none
                
            case .addStation:
                guard !state.title.isEmpty else {
                    return .run { send in
                        await send(.showEmptyTitleAlert)
                    }
                }
                
                guard !state.url.isEmpty, let contentURL = URL(string: state.url) else {
                    return .run { send in
                        await send(.showInvalidContentURLAlert)
                    }
                }
                
                if !state.imageURL.isEmpty {
                    guard URL(string: state.imageURL) != nil else {
                        return .run { send in
                            await send(.showInvalidImageURLAlert)
                        }
                    }
                }
                
                return .run { [state] send in
                    let id: String
                    switch state.mode {
                    case let .edit(stream):
                        id = stream.id
                    case .create:
                        id = UUID().uuidString
                    }
                    
                    let station = Stream(
                       id: id,
                       title: state.title,
                       description: state.description,
                       imageURL: URL(string: state.imageURL),
                       url: contentURL
                    )
                   
                    let file = try await state.containingDirectory.file(
                        name: station.id
                    )
                    try await file.save(station)
                    
                    await send(.delegate(.stationAdded))
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
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                
                TextField(
                    "Stream URL",
                    text: viewStore.binding(
                        get: \.url,
                        send: CreateStream.Action.setURL
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                TextField(
                    "Description",
                    text: viewStore.binding(
                        get: \.description,
                        send: CreateStream.Action.setDescription
                    )
                )
                .textInputAutocapitalization(.sentences)
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
                    switch viewStore.mode {
                    case .edit:
                        Text("Update")
                            .foregroundColor(.indigo)
                    case .create:
                        Text("Create")
                            .foregroundColor(.indigo)
                    }
                    
                }
            }
        }
        .alert(
            store: self.store.scope(state: \.$alert, action: { _ in .alertDismissed })
        )
    }
}

