//
//  StationsView.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 7/1/2023.
//

import SwiftUI
import ComposableArchitecture
import AVFAudio

struct Stations: ReducerProtocol {
    struct State: Equatable {
        var stations = [news, tripleJ, classic, kids]
        var selectedStation: RadioStation?
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected(RadioStation)
        }
        case delegate(Delegate)
        
        // Internal actions
        case selected(RadioStation)
    }
    
    @Dependency(\.player) var player
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .selected(station):
                return .concatenate(
                    .run { send in
                        AVAudioSession.sharedInstance().activate { _, error in
                            guard error == nil else {
                                // TODO: Deal with error
                                assertionFailure("Couldn't activate session")
                                return
                            }

                            Task {
                                player.play(station)
                                await send(.delegate(.selected(station)))
                            }
                        }
                    }
                )
            case .delegate:
                return .none
            }
        }
    }
}

struct StationsView: View {
    let store: StoreOf<Stations>
    @ObservedObject var viewStore: ViewStoreOf<Stations>
    
    init(store: StoreOf<Stations>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        List(viewStore.stations) { station in
            Button {
                viewStore.send(.selected(station))
            } label: {
                Text(station.title)
            }
        }
    }
}
