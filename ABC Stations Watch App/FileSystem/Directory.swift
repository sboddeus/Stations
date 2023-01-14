
import Foundation

/// An actor that coordinates access to a Directory in the FS.
public actor Directory {
    public enum BaseDirectory {
        case documents
        case caches
        case root

        indirect case directory(_: Directory)

        internal func url(fileManager: ABCFileManager) async -> URL? {
            switch self {
            case .documents:
                return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            case .caches:
                return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            case .root:
                return URL(fileURLWithPath: "/")
            case let .directory(dir):
                return try? await dir.url(fileManager: fileManager)
            }
        }
    }

    public enum Error: Swift.Error {
        case directoryURLError
    }

    let baseDirectory: BaseDirectory
    let path: URL
    let fileSystem: FileSystem
    
    init(baseDirectory: BaseDirectory, path: URL, fileSystem: FileSystem) {
        self.baseDirectory = baseDirectory
        self.path = path
        self.fileSystem = fileSystem
    }
    
    func url(fileManager: ABCFileManager) async throws -> URL {
        if let baseURL = await baseDirectory.url(fileManager: fileManager) {
            return baseURL.appendingPathComponent(path.path)
        } else {
            throw Error.directoryURLError
        }
    }
}

public extension Directory {
    
    /// Return a `File` belonging to and in the given `Directory`
    func file(name: String) async throws -> File {
        try await fileSystem.file(directory: self, name: name)
    }
    
    /// Returns a sub `Directory` in the given `Directory`
    func directory(path: URL) -> Directory {
        fileSystem.directory(in: self, path: path)
    }
    
    /// Create the directory object in the underlying OS File System
    func create() async throws {
        try await fileSystem.create(directory: self)
    }
    
    /// Retrives all the files contained withing the Directory.
    /// To retrieve subdirectories use `retrieveAllSubDirectories`
    func retrieveAllFiles() async throws -> [File] {
        try await fileSystem.retrieveAllFiles(from: self)
    }
    
    /// Retrieves all Directories contained within this Directory.
    /// To retrieve Files in the Directory use `retrieveAllFiles`
    func retrieveAllSubDirectories() async throws -> [Directory] {
        try await fileSystem.retrieveAllSubDirectories(from: self)
    }
    
    // In the future this should invalidate files
    /// Remove the Directory from the underlying OS File System
    func remove() async throws  {
        try await fileSystem.remove(self)
    }
    
    /// Returns a bool indicating if the Directory exists in the underlying OS File System.
    func exists() async -> Bool {
        await fileSystem.exists(self)
    }
}
