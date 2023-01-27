
import SwiftUI
import ComposableArchitecture

@main
struct Leincast_Watch_AppApp: App {
    let nowPlaying = NowPlayingControlsController()
    
    @Dependency(\.streamMaster) var stationMaster
    
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
