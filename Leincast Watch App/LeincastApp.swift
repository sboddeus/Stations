
import SwiftUI
import ComposableArchitecture

@main
struct Leincast_Watch_AppApp: App {
    let nowPlaying = NowPlayingControlsController()
    
    @Dependency(\.streamMaster) var stationMaster
    @Dependency(\.clipBoard) var clipBoard
    
    init() {
        nowPlaying.bind(toPlayer: .shared!)
        Task { [stationMaster, clipBoard] in
            await clipBoard.clearDirectory()
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
