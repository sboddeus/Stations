
import SwiftUI
import ComposableArchitecture

struct ClipBoardReducer: Reducer {
    struct State: Equatable {
        var content: IdentifiedArrayOf<ClipBoard.ContentType> = []
    }

    enum Action: Equatable {
        // Delegate
        enum Delegate: Equatable {
            case selected(ClipBoard.ContentType)
        }
        case delegate(Delegate)

        // Internal
        case onAppear
        case setContent([ClipBoard.ContentType])
    }

    @Dependency(\.clipBoard) var clipBoard

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let content = await clipBoard.content()
                    await send(.setContent(content))
                }
            case let .setContent(content):
                state.content = IdentifiedArrayOf(uniqueElements: content)
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

struct ClipBoardView: View {
    let store: StoreOf<ClipBoardReducer>
    @ObservedObject var viewStore: ViewStoreOf<ClipBoardReducer>

    init(store: StoreOf<ClipBoardReducer>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        List(viewStore.content) { content in
            switch content {
            case let .directory(dir):
                Button {
                    viewStore.send(.delegate(.selected(content)))
                } label: {
                    DirectoryRowCoreView(title: dir.name)
                }
            case let .stream(stream):
                Button {
                    viewStore.send(.delegate(.selected(content)))
                } label: {
                    StreamRowCoreView(
                        imageURL: stream.imageURL,
                        title: stream.title,
                        isActive: false) {
                            EmptyView()
                        }
                }
            }
        }.onAppear {
            viewStore.send(.onAppear)
        }
        .navigationTitle {
            Text("Select")
        }
    }
}
