
import SwiftUI
import ComposableArchitecture

@main
struct Leincast_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let nowPlaying = NowPlayingControlsController()
    
    @Dependency(\.playStatisticsDataService) var playStatisticsDataService
    @Dependency(\.clipBoard) var clipBoard
    @Dependency(\.podcastDataService) var podcastDataService

    let store: StoreOf<Home> = .init(initialState: .init(), reducer: { Home() })

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
            HomeView(store: store)
        }
        .onChange(of: scenePhase, { _, newPhase in
            if newPhase == .background {
                // Refresh again later
                WKApplication.shared().schedulePodcastRefresh()
            }
        })
        .backgroundTask(
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
        let preferredDate = Date().addingTimeInterval(60*60*4)// 4 hours later

        scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: BackgroundTaskIdentifiers.podcastRefresh.rawValue as NSString
        ) { error in
            if let error {
                assertionFailure("\(error.localizedDescription)")
            }
        }
    }
}
