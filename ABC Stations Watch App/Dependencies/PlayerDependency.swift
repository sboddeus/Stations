//
//  PlayerDependency.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 7/1/2023.
//

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
    var stationMaster: StationMaster {
        get { self[StationMasterKey.self] }
        set { self[StationMasterKey.self] = newValue }
    }

    enum StationMasterKey: DependencyKey {
        static let liveValue: StationMaster = .init()
    }
}
