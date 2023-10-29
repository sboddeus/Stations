
import SwiftUI
import ComposableArchitecture

struct AddPodcastFeature: Reducer {
    struct State: Equatable {
        var url: String = ""
        var isLoadingPodcast = false
        @PresentationState var alert: AlertState<Never>?
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

    @Dependency(\.podcastDataService) var podcastDataService

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alertDismissed:
                state.alert = nil
                return .none

            case let .setURL(url):
                state.url = url
                return .none

            case .podcastAddSuccess:
                state.isLoadingPodcast = false
                return .send(.delegate(.addedPodcast))

            case .podcastAddFailure:
                state.isLoadingPodcast = false
                state.alert = .init(
                    title: .init("Podcast Issue"),
                    message: .init("Ensure this podcast has not been added before and that the URL points to a valid RSS feed."),
                    dismissButton: .default(
                        .init("Ok")
                    )
                )
                return .none

            case .showInvalidContentURLAlert:
                state.alert = .init(
                    title: .init("Invalid podcast URL"),
                    message: .init("Ensure the url points to an RSS feed for a podcast"),
                    dismissButton: .default(
                        .init("Ok")
                    )
                )
                return .none

            case .addPodcast:
                guard !state.url.isEmpty, let contentURL = URL(string: state.url) else {
                    return .run { send in
                        await send(.showInvalidContentURLAlert)
                    }
                }

                state.isLoadingPodcast = true
                return .run { send in
                    do {
                        _ = try await podcastDataService.addPodcast(at: contentURL)

                        await send(.podcastAddSuccess)
                    } catch {
                        await send(.podcastAddFailure)
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

            if viewStore.isLoadingPodcast {
                ProgressView()
            } else {
                Button {
                    viewStore.send(.addPodcast)
                } label: {
                    Text("Create")
                        .foregroundColor(.indigo)
                }
            }
        }
        .alert(
            store: self.store.scope(state: \.$alert, action: { _ in .alertDismissed })
        )
    }
}
