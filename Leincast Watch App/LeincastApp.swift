
import SwiftUI
import ComposableArchitecture

@main
struct Leincast_Watch_AppApp: App {
    let nowPlaying = NowPlayingControlsController()
    
    @Dependency(\.playStatisticsDataService) var playStatisticsDataService
    @Dependency(\.clipBoard) var clipBoard
    @Dependency(\.podcastDataService) var podcastDataService
    
    init() {
        nowPlaying.bind(toPlayer: .shared!)
        Task { [playStatisticsDataService, clipBoard, podcastDataService] in
            await clipBoard.initialise()
            await podcastDataService.initialise(with: .shared!)
            await playStatisticsDataService.bind(to: .shared!)
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
