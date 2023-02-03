
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