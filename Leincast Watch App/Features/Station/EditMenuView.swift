
import Foundation
import SwiftUI
import ComposableArchitecture

struct EditMenu: Reducer {
    struct State: Equatable {
        var showPasteOption = false
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case addStation
            case addFolder
            case paste
        }
        case delegate(Delegate)
        
        case onAppear
        case setShowPasteOption(Bool)
    }
    
    @Dependency(\.clipBoard) var clipBoard
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let show = await !clipBoard.content().isEmpty
                    await send(.setShowPasteOption(show))
                }
                
            case let .setShowPasteOption(show):
                state.showPasteOption = show
                return .none
                
            case .delegate:
                return .none
            }
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
            
            if viewStore.showPasteOption {
                Button {
                    viewStore.send(.delegate(.paste))
                } label: {
                    HStack {
                        Text("Paste")
                            .foregroundColor(.indigo)
                        Spacer()
                        Image(systemName: "doc.on.clipboard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.indigo)
                    }
                }
            }
        }.onAppear {
            viewStore.send(.onAppear)
        }
    }
}

