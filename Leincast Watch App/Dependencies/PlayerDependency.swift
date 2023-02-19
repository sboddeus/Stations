
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
    var streamMaster: StreamMaster {
        get { self[StationMasterKey.self] }
        set { self[StationMasterKey.self] = newValue }
    }

    enum StationMasterKey: DependencyKey {
        static let liveValue: StreamMaster = .init()
    }
}

extension DependencyValues {
    var podcastMaster: PodcastMaster {
        get { self[PodcastMasterKey.self] }
        set { self[PodcastMasterKey.self] = newValue }
    }

    enum PodcastMasterKey: DependencyKey {
        static let liveValue: PodcastMaster = .init()
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
