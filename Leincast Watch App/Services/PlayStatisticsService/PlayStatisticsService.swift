//
//  PlayStatisticsService.swift
//  Leincast Watch App
//
//  Created by Sye Boddeus on 30/4/2023.
//

import Foundation
import Collections

actor PlayStatisticsService {

    private var filesystem: FileSystem = .default

    private lazy var recentsFile: File = {
        let dir = Directory(
            baseDirectory: .documents,
            path: URL(string: "recents")!,
            fileSystem: filesystem
        )
        return File(
            directory: dir,
            name: "recents",
            fileSystem: filesystem
        )
    }()

    func recents() async -> [MediaItem] {
        let recents = (try? await recentsFile.retrieve(as: Deque<MediaItem>.self)) ?? []
        return Array(recents)
    }

    private var bindTask: Task<(), Never>?
    func bind(to player: AVAudioPlayer) {
        bindTask?.cancel()
        bindTask = Task {
            var recents: Deque<MediaItem>  = (try? await recentsFile.retrieve(as: Deque<MediaItem>.self)) ?? []
            for await value in player.playingState.values {
                switch value {
                case let .loading(item):
                    recents.removeAll { $0.id == item.id }
                    recents.insert(item, at: 0)
                    if recents.count > 3 {
                        _ = recents.popLast()
                    }

                    try? await recentsFile.save(recents)
                default:
                    break
                }
            }
        }
    }

    deinit {
        bindTask?.cancel()
    }
}
