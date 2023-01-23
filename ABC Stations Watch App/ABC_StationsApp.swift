//
//  ABC_StationsApp.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 7/1/2023.
//

import SwiftUI
import ComposableArchitecture

@main
struct ABC_Stations_Watch_AppApp: App {
    let nowPlaying = NowPlayingControlsController()
    
    @Dependency(\.stationMaster) var stationMaster
    init() {
        nowPlaying.bind(toPlayer: .shared!)
        Task { [stationMaster] in
            await stationMaster.bind(to: .shared!)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView(
                store: .init(
                    initialState: .init(),
                    reducer: Home()
                )
            )
        }
    }
}
