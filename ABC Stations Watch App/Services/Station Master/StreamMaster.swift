
import Foundation
import Collections
import AsyncAlgorithms
import AVFAudio

actor StreamMaster {
    
    private var filesystem: FileSystem = .default
    private var defaults: UserDefaults = .standard
    private var rootPath = URL(string: "/Streams")!
    private var volumeObserver: NSKeyValueObservation?
    
    nonisolated
    var volume: Double {
        Double(AVAudioSession.sharedInstance().outputVolume)
    }
    
    var rootDirectory: Directory {
        filesystem.directory(
            inBase: .documents,
            path: rootPath
        )
    }
    
    private lazy var recentsFile: File = {
        let dir = Directory(
            baseDirectory: .documents,
            path: URL(string: "/recents")!,
            fileSystem: filesystem
        )
        return File(
            directory: dir,
            name: "recents",
            fileSystem: filesystem
        )
    }()
    
    func recents() async -> [Station] {
        let recents = (try? await recentsFile.retrieve(as: Deque<Station>.self)) ?? []
        return Array(recents)
    }
    
    private var bindTask: Task<(), Never>?
    func bind(to player: AVAudioPlayer) {
        bindTask?.cancel()
        bindTask = Task {
            var recents: Deque<Station>  = (try? await recentsFile.retrieve(as: Deque<Station>.self)) ?? []
            for await value in player.playingState.values {
                switch value {
                case let .loading(station):
                    recents.removeAll { $0.id == station.id }
                    recents.insert(station, at: 0)
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
    
    func constructInitialSystemIfNeeded() async {
        let initialConstructionKey = "fs.version.0";
        guard !defaults.bool(forKey: initialConstructionKey) else {
            // Our work is done
            return
        }
        
        // Version 0 of the initial folders
        let dir = rootDirectory
        try? await dir.remove()
        
        // Australian
        let aus = await dir.directory(path: URL(string: "Australia")!)
        
        let abc = await aus.directory(path: URL(string: "ABC")!)
        try? await abc.file(name: tripleJ.id.uuidString).save(tripleJ)
        try? await abc.file(name: news.id.uuidString).save(news)
        try? await abc.file(name: classic.id.uuidString).save(classic)
        try? await abc.file(name: kids.id.uuidString).save(kids)
        
        let sbs = await aus.directory(path: URL(string: "SBS")!)
        try? await sbs.file(name: SBS.id.uuidString).save(SBS)
        
        let commercial = await aus.directory(path: URL(string: "Commercial")!)
        try? await commercial.file(name: tikTokTrending.id.uuidString).save(tikTokTrending)
        try? await commercial.file(name: hitFM.id.uuidString).save(hitFM)
        
        // UK
        let uk = await dir.directory(path: URL(string: "UK")!)
        let bbc = await uk.directory(path: URL(string: "BBC")!)
        try? await bbc.file(name: bbcWorldwide.id.uuidString).save(bbcWorldwide)
        
        // US
        let us = await dir.directory(path: URL(string: "US")!)
        try? await us.file(name: bin.id.uuidString).save(bin)
        
        // Finally, update user defaults
        defaults.set(true, forKey: initialConstructionKey)
    }
    
    deinit {
        volumeObserver?.invalidate()
        bindTask?.cancel()
    }
}

extension Directory {
    func getAllStations() async -> [Station] {
        guard let files = try? await retrieveAllFiles() else {
            return []
        }
        
        let nilStations = await files.asyncMap {
            try? await $0.retrieve(as: Station.self)
        }
        
        return nilStations.compactMap { $0 }
    }
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}
