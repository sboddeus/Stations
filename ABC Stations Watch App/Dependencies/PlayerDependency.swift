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
