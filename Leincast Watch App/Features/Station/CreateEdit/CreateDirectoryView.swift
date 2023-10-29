
import SwiftUI
import ComposableArchitecture

enum CreateDirectoryError: Error {
    case couldntCreateValidURL
}

struct CreateDirectory: Reducer {
    struct State: Equatable {
        let containingDirectory: Directory
        var title: String = ""
        @PresentationState var alert: AlertState<Never>?
    }
    
    enum Action: Equatable {
        case setTitle(String)
        case addDirectory
        case showDirectoryAlert
        case alertDismissed
        
        enum Delegate {
            case directoryAdded
        }
        case delegate(Delegate)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setTitle(title):
                state.title = title
                return .none

            case .alertDismissed:
                state.alert = nil
                return .none

            case .showDirectoryAlert:
                state.alert = .init(
                    title: .init("Could not create folder"),
                    message: .init("Ensure the folder has a unique name and that device storage is not full."),
                    dismissButton: .default(
                        .init("Ok")
                    )
                )
                return .none

            case .addDirectory:
                return .run { [state] send in
                    do {
                        guard let stringPath = state.title
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .addingPercentEncoding(
                                withAllowedCharacters: .urlPathAllowed
                            ) else {
                            throw CreateDirectoryError.couldntCreateValidURL
                        }
                        guard let path = URL(string: stringPath) else {
                            throw CreateDirectoryError.couldntCreateValidURL
                        }

                        try await state.containingDirectory
                            .directory(path: path)
                            .create()

                        await send(.delegate(.directoryAdded))
                    } catch {
                        await send(.showDirectoryAlert)
                    }
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
        .alert(
            store: self.store.scope(state: \.$alert, action: { _ in .alertDismissed })
        )
    }
}
