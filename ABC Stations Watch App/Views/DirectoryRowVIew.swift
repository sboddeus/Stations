
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
            Text(viewStore.directory.name)
        }
    }
}
