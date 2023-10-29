
import SwiftUI
import ComposableArchitecture

struct EditDirectory: Reducer {
    struct State: Equatable {
        let editedDirectory: Directory
        var title: String = ""
        
        init(editedDirectory: Directory) {
            self.editedDirectory = editedDirectory
            self.title = editedDirectory.name
        }
    }
    
    enum Action: Equatable {
        case setTitle(String)
        case editDirectory
        
        enum Delegate: Equatable {
            case directoryEdited(Directory)
        }
        case delegate(Delegate)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setTitle(title):
                state.title = title
                return .none
                
            case .editDirectory:
                return .run { [state] send in
                    let dir = try await state.editedDirectory
                        .rename(
                            to: state.title
                        )
                    
                     await send(.delegate(.directoryEdited(dir)))
                }
            case .delegate:
                return .none
            }
        }
    }
}

struct EditDirectoryView: View {
    let store: StoreOf<EditDirectory>
    @ObservedObject var viewStore: ViewStoreOf<EditDirectory>
    
    init(store: StoreOf<EditDirectory>) {
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
                        send: EditDirectory.Action.setTitle
                    )
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                Button {
                    viewStore.send(.editDirectory)
                } label: {
                    Text("Update")
                        .foregroundColor(.indigo)
                }.disabled(viewStore.title.isEmpty)
            }
        }
    }
}
