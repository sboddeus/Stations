
import Foundation

actor StationMaster {
    
    private var stationCache: [RadioStation]? = nil
    private var filesystem: FileSystem = .default
    private var stationFile: File? = nil
    
    func add(station: RadioStation) async {
        if stationCache == nil {
            _ = await getStations()
        }
        
        stationCache?.append(station)
        
        await save()
    }
    
    func remove(stationId: String) async {
        if stationCache == nil {
            _ = await getStations()
        }
        stationCache?.removeAll(where: { $0.id == stationId })
        
        await save()
    }
    
    func update(station: RadioStation, to newStation: RadioStation) async {
        if stationCache == nil {
            _ = await getStations()
        }
        
        stationCache?.removeAll(where: { cached in
            cached.id == station.id
        })
        
        stationCache?.append(newStation)
        
        await save()
    }
    
    func getStations() async -> [RadioStation] {
        guard let stations = stationCache else {
            if let stations = await load(),
                !stations.isEmpty {
                stationCache = stations
                return stations
            } else {
                stationCache = ABCStations
                await save()
                return ABCStations
            }
        }
        
        return stations
    }
    
    private func load() async -> [RadioStation]? {
        if stationFile == nil {
            let dir = filesystem.directory(inBase: .documents, path: URL(string: "/stations")!)
            stationFile = try! await dir.file(name: "stations")
        }
        return try? await stationFile!.retrieve(as: [RadioStation].self)
    }
    
    private func save() async {
        if let stationCache {
            
            if stationFile == nil {
                let dir = filesystem.directory(inBase: .documents, path: URL(string: "/stations")!)
                stationFile = try! await dir.file(name: "stations")
            }
            
            try? await stationFile!.save(stationCache)
        }
    }
}
