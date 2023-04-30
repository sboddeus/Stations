
import Foundation
import ComposableArchitecture

extension DependencyValues {
    var player: AVAudioPlayer {
        get { self[AVAudioPlayerKey.self] }
        set { self[AVAudioPlayerKey.self] = newValue }
    }

    enum AVAudioPlayerKey: DependencyKey {
        static let liveValue: AVAudioPlayer = .shared!
    }
}

extension DependencyValues {
    var streamDataService: StreamsDataService {
        get { self[StationMasterKey.self] }
        set { self[StationMasterKey.self] = newValue }
    }

    enum StationMasterKey: DependencyKey {
        static let liveValue: StreamsDataService = .init()
    }
}

extension DependencyValues {
    var playStatisticsDataService: PlayStatisticsService {
        get { self[PlayStatisticsServiceKey.self] }
        set { self[PlayStatisticsServiceKey.self] = newValue }
    }

    enum PlayStatisticsServiceKey: DependencyKey {
        static let liveValue: PlayStatisticsService = .init()
    }
}

extension DependencyValues {
    var podcastDataService: PodcastDataService {
        get { self[PodcastMasterKey.self] }
        set { self[PodcastMasterKey.self] = newValue }
    }

    enum PodcastMasterKey: DependencyKey {
        static let liveValue: PodcastDataService = .init()
    }
}

extension DependencyValues {
    var userDefaults: UserDefaults {
        get { self[UserDefaultsKey.self] }
        set { self[UserDefaultsKey.self] = newValue }
    }
    
    enum UserDefaultsKey: DependencyKey {
        static let liveValue: UserDefaults = .standard
    }
}

extension DependencyValues {
    var clipBoard: ClipBoard {
        get { self[ClipBoardKey.self] }
        set { self[ClipBoardKey.self] = newValue }
    }
    
    enum ClipBoardKey: DependencyKey {
        static let liveValue: ClipBoard = .init()
    }
}
