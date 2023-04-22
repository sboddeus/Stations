
import SwiftUI
import ComposableArchitecture

@main
struct Leincast_Watch_AppApp: App {
    let nowPlaying = NowPlayingControlsController()
    
    @Dependency(\.streamMaster) var stationMaster
    @Dependency(\.clipBoard) var clipBoard
    @Dependency(\.podcastMaster) var podcastMaster
    
    init() {
        nowPlaying.bind(toPlayer: .shared!)
        Task { [stationMaster, clipBoard, podcastMaster] in
            await clipBoard.initialise()
            await podcastMaster.initialise()
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
