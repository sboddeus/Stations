
import Foundation

actor StationMaster {
    
    private var filesystem: FileSystem = .default
    private var defaults: UserDefaults = .standard
    private var rootPath = URL(string: "/stations")!
    
    var rootDirectory: Directory {
        filesystem.directory(
            inBase: .documents,
            path: rootPath
        )
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
        
        // UK
        let uk = await dir.directory(path: URL(string: "UK")!)
        let bbc = await uk.directory(path: URL(string: "BBC")!)
        try? await bbc.file(name: bbcWorldwide.id.uuidString).save(bbcWorldwide)
        
        // Finally, update user defaults
        defaults.set(true, forKey: initialConstructionKey)
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
