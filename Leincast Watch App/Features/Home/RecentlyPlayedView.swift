
import SwiftUI
import ComposableArchitecture
import AVFAudio

struct RecentlyPlayed: Reducer {
    struct State: Equatable {
        var items: IdentifiedArrayOf<RecentlyPlayedRowFeature.State> = []
    }
    
    enum Action: Equatable {
        case onAppear
        case update([MediaItem])
        case item(id: RecentlyPlayedRowFeature.State.ID, action: RecentlyPlayedRowFeature.Action)
    }
    
    @Dependency(\.playStatisticsDataService) var playStatisticsDataService
    @Dependency(\.player) var player
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let recents = await playStatisticsDataService.recents()
                    await send(.update(recents))
                }
            case let .update(items):
                state.items = IdentifiedArray(
                    uniqueElements: items.map {
                        RecentlyPlayedRowFeature.State(item: $0, activeState: .unselected)
                    }
                )
                return .none
            case let .item(id, .delegate(.selected)):
                if let item = state.items[id: id] {
                    return .run { _ in
                        AVAudioSession.sharedInstance().activate { _, error in
                            guard error == nil else {
                                // TODO: Deal with error
                                assertionFailure("Couldn't activate session")
                                return
                            }
                            
                            player.play(item.item)
                        }
                        
                    }
                }
                return .none
                
            case .item:
                return .none
            }
        }
        .forEach(\.items, action: /Action.item) {
            RecentlyPlayedRowFeature()
        }
    }
}

struct RecentlyPlayedView: View {
    let store: StoreOf<RecentlyPlayed>
    @ObservedObject var viewStore: ViewStoreOf<RecentlyPlayed>
    
    init(store: StoreOf<RecentlyPlayed>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        VStack {
            if viewStore.items.isEmpty {
                Text("No streams played yet").font(.body)
            }
            ForEachStore(
                store.scope(
                    state: \.items,
                    action: RecentlyPlayed.Action.item(id:action:))
            ) { store in
                RecentlyPlayedRow(store: store)
            }
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
    }
}

import SDWebImageSwiftUI

struct RecentlyPlayedRowFeature: Reducer {
    struct State: Equatable, Identifiable {
        let item: MediaItem

        enum ActiveState: Equatable {
            case paused
            case playing
            case loading
            case unselected
        }
        var activeState: ActiveState

        var id: String {
            item.id
        }
    }

    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected
        }
        case delegate(Delegate)

        case play
        case pause

        case playerBinding

        case setActiveState(State.ActiveState)
    }

    @Dependency(\.player) var player

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setActiveState(activeState):
                state.activeState = activeState
                return .none

            case .play:
                return .run { _ in
                    player.play()
                }

            case .pause:
                return .run { _ in
                    player.pause()
                }

            case .delegate:
                return .none

            case .playerBinding:
                let stationId = state.item.id
                return .run { send in
                    for await value in player.playingState.values {
                        guard value.stationId == stationId else {
                            await send(.setActiveState(.unselected))
                            continue
                        }

                        switch value {
                        case .loading:
                            await send(.setActiveState(.loading))
                        case .paused:
                            await send(.setActiveState(.paused))
                        case .playing:
                            await send(.setActiveState(.playing))
                        case .initial, .stopped:
                            await send(.setActiveState(.unselected))
                        }
                    }
                }
            }
        }
    }
}

struct RecentlyPlayedRow: View {
    let store: StoreOf<RecentlyPlayedRowFeature>
    @ObservedObject var viewStore: ViewStoreOf<RecentlyPlayedRowFeature>

    init(store: StoreOf<RecentlyPlayedRowFeature>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }

    var body: some View {
        Button {
            viewStore.send(.delegate(.selected))
        } label: {
            StreamRowCoreView(
                imageURL: viewStore.item.imageURL,
                title: viewStore.item.title,
                isActive: viewStore.activeState == .unselected) {
                    switch viewStore.activeState {
                    case .loading:
                        ProgressView()
                            .foregroundColor(.red)
                            .scaledToFit()
                            .fixedSize()
                    case .playing:
                        Image(systemName: "pause.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                            .onTapGesture {
                                viewStore.send(.pause)
                            }
                    case .paused:
                        Image(systemName: "play.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                            .onTapGesture {
                                viewStore.send(.play)
                            }
                    case .unselected:
                        EmptyView()
                    }
                }
        }
        .task {
            await viewStore.send(.playerBinding).finish()
        }
    }
}
