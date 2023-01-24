
import SwiftUI
import ComposableArchitecture

struct CreateDirectory: ReducerProtocol {
    struct State: Equatable {
        let containingDirectory: Directory
        var title: String = ""
    }
    
    enum Action: Equatable {
        case setTitle(String)
        case addDirectory
        
        enum Delegate {
            case directoryAdded
        }
        case delegate(Delegate)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setTitle(title):
                state.title = title
                return .none
            case .addDirectory:
                return .task { [state] in
                    try await state.containingDirectory
                        .directory(
                            // TODO: URL validation here
                            path: URL(string:
                                        state.title.trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        )
                                     )!
                        )
                        .create()
                    
                    return .delegate(.directoryAdded)
                }
                
            case .delegate:
                return .none
            }
        }
    }
}

struct CreateDirectoryView: View {
    let store: StoreOf<CreateDirectory>
    @ObservedObject var viewStore: ViewStoreOf<CreateDirectory>
    
    init(store: StoreOf<CreateDirectory>) {
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
                        send: CreateDirectory.Action.setTitle
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                Button {
                    viewStore.send(.addDirectory)
                } label: {
                    Text("Create")
                        .foregroundColor(.indigo)
                }.disabled(viewStore.title.isEmpty)
            }
        }
    }
}
