//
//  ABC_StationsApp.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 7/1/2023.
//

import SwiftUI

@main
struct ABC_Stations_Watch_AppApp: App {
    let nowPlaying = NowPlayingControlsController()
    
    init() {
        nowPlaying.bind(toPlayer: .shared!)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(
                store: .init(
                    initialState: .init(),
                    reducer: Root()
                )
            )
        }
    }
}
