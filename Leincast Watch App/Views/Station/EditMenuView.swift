
import Foundation
import SwiftUI
import ComposableArchitecture

struct EditMenu: ReducerProtocol {
    struct State: Equatable {
        // This is here to give this a stable state
        // Not having any field here caused issues with creating a stream view.
        // Kind of if the reducer stack was triggering state changes effecting child views.
        // Not sure why that happened. But remove if other more important state is here.
        let id = "Delete me if other state is here"
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case addStation
            case addFolder
        }
        case delegate(Delegate)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}

struct EditMenuView: View {
    let store: StoreOf<EditMenu>
    @ObservedObject var viewStore: ViewStoreOf<EditMenu>
    
    init(store: StoreOf<EditMenu>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        List {
            Button {
                viewStore.send(.delegate(.addFolder))
            } label: {
                HStack {
                    Text("Add folder")
                        .foregroundColor(.green)
                    Spacer()
                    Image(systemName: "folder.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.green)
                }
            }
            
            Button {
                viewStore.send(.delegate(.addStation))
            } label: {
                HStack {
                    Text("Add live stream")
                        .foregroundColor(.green)
                    Spacer()
                    Image(systemName: "radio.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

