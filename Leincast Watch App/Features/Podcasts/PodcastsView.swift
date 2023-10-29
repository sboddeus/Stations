
import Foundation
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct Podcasts: Reducer {
    struct State: Equatable {
        enum Route: Equatable {
            case podcastDetails(PodcastDetails.State)
            case addPodcast(AddPodcastFeature.State)
        }
        var route: Route?

        var podcastRows: IdentifiedArrayOf<PodcastRowFeature.State> = []

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.podcastRows == rhs.podcastRows &&
            lhs.route == rhs.route
        }
    }

    enum Action: Equatable {
        // Internal
        case onAppear
        case setPodcasts([Podcast])
        case showAddPodcast
        case setRoute(State.Route?)

        // Child
        enum RouteAction: Equatable {
            case podcastDetails(PodcastDetails.Action)
            case addPodcast(AddPodcastFeature.Action)
        }
        case routeAction(RouteAction)

        case podcastRow(id: PodcastRowFeature.State.ID, action: PodcastRowFeature.Action)
    }

    @Dependency(\.podcastDataService) var podcastDataService

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let podcasts = await podcastDataService.getAllPodcasts()

                    await send(.setPodcasts(podcasts))
                }

            case let .setPodcasts(podcasts):
                state.podcastRows = .init(uniqueElements: podcasts.map {
                    PodcastRowFeature.State(id: $0.id, title: $0.title, imageURL: $0.imageURL)
                })
                return .none

            case .showAddPodcast:
                state.route = .addPodcast(.init())
                return .none

            case let .setRoute(route):
                state.route = route
                return .none

            case .routeAction(.addPodcast(.delegate(.addedPodcast))):
                state.route = nil
                return .send(.onAppear)

            case .routeAction:
                return .none


            case let .podcastRow(id, .delegate(.deleted)):
                return .run { send in
                    try await  podcastDataService.delete(podcastId: id)
                    await send(.onAppear)
                }

            case let .podcastRow(id, .delegate(.selected)):
                if let podcast = state.podcastRows[id: id] {
                    state.route = .podcastDetails(.init(id: podcast.id))
                }
                return .none
            }
        }
        .ifLet(\.route, action: /Action.routeAction) {
            Scope(state: /State.Route.addPodcast, action: /Action.RouteAction.addPodcast) {
                AddPodcastFeature()
            }
            Scope(state: /State.Route.podcastDetails, action: /Action.RouteAction.podcastDetails) {
                PodcastDetails()
            }
        }
        .forEach(\.podcastRows, action: /Action.podcastRow(id:action:)) {
            PodcastRowFeature()
        }
    }
}

struct PodcastsView: View {
    struct ViewState: Equatable {
        let route: Podcasts.State.Route?
        let podcastRows: IdentifiedArrayOf<PodcastRowFeature.State>

        init(state: Podcasts.State) {
            route = state.route
            podcastRows = state.podcastRows
        }
    }

    let store: StoreOf<Podcasts>
    @ObservedObject var viewStore: ViewStore<ViewState, Podcasts.Action>

    init(store: StoreOf<Podcasts>) {
        self.store = store
        viewStore = .init(store, observe: ViewState.init)
    }

    var body: some View {
        List {
            ForEachStore(self.store.scope(
                state: \.podcastRows,
                action: Podcasts.Action.podcastRow(id:action:))
            ) { store in
                PodcastRow(store: store)
            }

            Section {
                Button {
                    viewStore.send(.showAddPodcast)
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.green)
                        Text("Add")
                            .foregroundColor(.green)
                        Spacer()
                    }
                }
            }
        }
        .navigationDestination(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Podcasts.Action.setRoute
            ),
            case: /Podcasts.State.Route.podcastDetails
        ) { $binding in
                let store = store.scope(
                    state: { $0.route.flatMap(/Podcasts.State.Route.podcastDetails) ?? binding },
                    action: { Podcasts.Action.routeAction(.podcastDetails($0)) }
                )
                PodcastDetailsView(store: store)
            }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.route,
                send: Podcasts.Action.setRoute
            ),
            case: /Podcasts.State.Route.addPodcast
        ) { $value in
            let store = store.scope(
                state: { $0.route.flatMap(/Podcasts.State.Route.addPodcast) ?? value },
                action: { Podcasts.Action.routeAction(.addPodcast($0)) }
            )
            AddPodcast(store: store)
                .interactiveDismissDisabled()
        }
        .task {
            await viewStore.send(.onAppear).finish()
        }
    }
}

