
import Foundation
import SwiftUI
import ComposableArchitecture

struct DirectoryRow: ReducerProtocol {
    struct State: Equatable, Identifiable {
        let directory: Directory
        
        var id: String {
            directory.path.absoluteString
        }
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected
            case edit
            case delete
            case copy
            case duplicate
        }
        case delegate(Delegate)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}

struct DirectoryRowView: View {
    let store: StoreOf<DirectoryRow>
    @ObservedObject var viewStore: ViewStoreOf<DirectoryRow>
    
    init(store: StoreOf<DirectoryRow>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        Button {
            viewStore.send(.delegate(.selected))
        } label: {
            DirectoryRowCoreView(title: viewStore.directory.name)
        }
        .swipeActions(edge: .trailing) {
            Button {
                viewStore.send(.delegate(.edit))
            } label: {
                Image(systemName: "pencil")
            }
            .tint(.indigo)

            Button(role: .destructive) {
                viewStore.send(.delegate(.delete))
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading) {
            Button {
                viewStore.send(.delegate(.copy))
            } label: {
                Image(systemName: "scissors")
            }
            .tint(.indigo)

            Button {
                viewStore.send(.delegate(.duplicate))
            } label: {
                Image(systemName: "doc.on.doc.fill")
            }
            .tint(.indigo)
        }
    }
}

struct DirectoryRowCoreView: View {

    let title: String

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(title)
            Spacer()
        }
    }
}
