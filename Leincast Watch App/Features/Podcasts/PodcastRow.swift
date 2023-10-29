
import Foundation
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct PodcastRowFeature: Reducer {
    struct State: Equatable, Identifiable {
        let id: String
        let title: String
        let imageURL: URL?
    }

    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected
            case deleted
        }

        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}

struct PodcastRow: View {
    let store: StoreOf<PodcastRowFeature>
    @ObservedObject var viewStore: ViewStoreOf<PodcastRowFeature>

    init(store: StoreOf<PodcastRowFeature>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        HStack {
            if let imageURL = viewStore.imageURL {
                WebImage(url: imageURL)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 30, maxHeight: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Color.white
                    .frame(maxWidth: 30, maxHeight: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(viewStore.title)

            Spacer()
        }
        .onTapGesture {
            viewStore.send(.delegate(.selected))
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewStore.send(.delegate(.deleted))
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }
}
