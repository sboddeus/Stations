
import Foundation
import SwiftUI
import ComposableArchitecture
import SDWebImageSwiftUI

struct Podcasts: ReducerProtocol {
    struct State: Equatable {
        var isLoading = true
        var podcasts: [Podcast] = []

        enum Route: Equatable {
            case podcastDetails(PodcastDetails.State)
            case addPodcast(AddPodcastFeature.State)
        }
        var route: Route?
    }

    enum Action: Equatable {
        // Internal
        case onAppear
        case setPodcasts([Podcast])
        case selected(Podcast)
        case showAddPodcast
        case setRoute(State.Route?)

        // Child
        enum RouteAction: Equatable {
            case podcastDetails(PodcastDetails.Action)
            case addPodcast(AddPodcastFeature.Action)
        }
        case routeAction(RouteAction)
    }

    @Dependency(\.podcastMaster) var podcastMaster

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .task {
                    let podcasts = await podcastMaster.getAllPodcasts()

                    return .setPodcasts(podcasts)
                }

            case let .setPodcasts(podcasts):
                state.podcasts = podcasts
                state.isLoading = false
                return .none

            case .showAddPodcast:
                state.route = .addPodcast(.init())
                return .none

            case let .selected(podcast):
                state.route = .podcastDetails(.init(podcast: podcast))
                return .none

            case let .setRoute(route):
                state.route = route
                return .none

            case .routeAction(.addPodcast(.delegate(.addedPodcast))):
                state.route = nil
                return .send(.onAppear)

            case .routeAction:
                return .none
            }
        }.ifLet(\.route, action: /Action.routeAction) {
            Scope(state: /State.Route.addPodcast, action: /Action.RouteAction.addPodcast) {
                AddPodcastFeature()
            }
            Scope(state: /State.Route.podcastDetails, action: /Action.RouteAction.podcastDetails) {
                PodcastDetails()
            }
        }
    }
}

struct PodcastsView: View {
    let store: StoreOf<Podcasts>
    @ObservedObject var viewStore: ViewStoreOf<Podcasts>

    init(store: StoreOf<Podcasts>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        List {
            if viewStore.isLoading {
                HStack {
                    Text("Lorem ipsum podcastium")
                    Spacer()
                }
                .redacted(reason: .placeholder)
            }
            ForEach(viewStore.podcasts) { podcast in
                HStack {
                    WebImage(url: podcast.imageURL)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 30, maxHeight: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(podcast.title)

                    Spacer()
                }
                .onTapGesture {
                    viewStore.send(.selected(podcast))
                }
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
        .onAppear {
            viewStore.send(.onAppear)
        }
    }
}

