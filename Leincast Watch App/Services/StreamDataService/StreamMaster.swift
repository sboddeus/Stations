
import Foundation
import AsyncAlgorithms
import AVFAudio

actor StreamsDataService {
    
    private var filesystem: FileSystem = .default
    private var defaults: UserDefaults = .standard
    private var rootPath = URL(string: "Streams")!

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
}

extension Directory {
    func getAllStations() async -> [Stream] {
        guard let files = try? await retrieveAllFiles() else {
            return []
        }
        
        let nilStations = await files.asyncMap {
            try? await $0.retrieve(as: Stream.self)
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
