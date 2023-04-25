
import SwiftUI
import ComposableArchitecture

struct AddPodcastFeature: ReducerProtocol {
    struct State: Equatable {
        var url: String = ""
        var alert: AlertState<Action>?
    }

    enum Action: Equatable {

        // Internal
        case setURL(String)
        case addPodcast
        case podcastAddSuccess
        case podcastAddFailure
        case showInvalidContentURLAlert
        case alertDismissed

        // Delegate
        enum Delegate: Equatable {
            case addedPodcast
        }
        case delegate(Delegate)
    }

    @Dependency(\.podcastMaster) var podcastMaster

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .alertDismissed:
                state.alert = nil
                return .none

            case let .setURL(url):
                state.url = url
                return .none

            case .podcastAddSuccess:
                return .send(.delegate(.addedPodcast))

            case .podcastAddFailure:
                state.alert = .init(
                    title: .init("Podcast Issue"),
                    message: .init("Ensure this podcast has not been added before and that the URL points to a valid RSS feed."),
                    dismissButton: .default(
                        .init("Ok"),
                        action: .send(.alertDismissed)
                    )
                )
                return .none

            case .showInvalidContentURLAlert:
                state.alert = .init(
                    title: .init("Invalid podcast URL"),
                    message: .init("Ensure the url points to an RSS feed for a podcast"),
                    dismissButton: .default(
                        .init("Ok"),
                        action: .send(.alertDismissed)
                    )
                )
                return .none

            case .addPodcast:
                guard !state.url.isEmpty, let contentURL = URL(string: state.url) else {
                    return .task {
                        return .showInvalidContentURLAlert
                    }
                }

                return .task {
                    do {
                        _ = try await podcastMaster.addPodcast(at: contentURL)

                        return .podcastAddSuccess
                    } catch {
                        return .podcastAddFailure
                    }
                }

            case .delegate:
                return .none
            }
        }
    }
}

struct AddPodcast: View {
    let store: StoreOf<AddPodcastFeature>
    @ObservedObject var viewStore: ViewStoreOf<AddPodcastFeature>

    init(store: StoreOf<AddPodcastFeature>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        VStack {
            TextField(
                "Podcast URL",
                text: viewStore.binding(
                    get: \.url,
                    send: AddPodcastFeature.Action.setURL
                )
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)

            Spacer()

            Button {
                viewStore.send(.addPodcast)
            } label: {
                Text("Create")
                    .foregroundColor(.indigo)
            }
        }.alert(
            self.store.scope(
                state: \.alert
            ),
            dismiss: AddPodcastFeature.Action.alertDismissed
        )
    }
}
