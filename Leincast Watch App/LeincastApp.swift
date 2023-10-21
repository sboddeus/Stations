
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
            ).onAppear {
                // Refresh again later
                WKApplication.shared().schedulePodcastRefresh()
            }
        }.backgroundTask(
            .appRefresh(BackgroundTaskIdentifiers.podcastRefresh.rawValue)
        ) { _ in
            for podcast in await podcastDataService.getAllPodcasts() {
                _ = try? await podcastDataService.refresh(podcastId: podcast.id)
            }

            // Refresh again later
            await WKApplication.shared().schedulePodcastRefresh()
        }
    }
}

extension WKApplication {
    func schedulePodcastRefresh() {
        let preferredDate = Date().addingTimeInterval(60*60*12)// 12 hours later

        scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: BackgroundTaskIdentifiers.podcastRefresh.rawValue as NSSecureCoding & NSObjectProtocol
        ) { error in
            //TODO: Log error somewhere
            guard error == nil else {
                return
            }
        }
    }
}
