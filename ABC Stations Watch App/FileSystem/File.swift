
import Foundation

/// This actor coordinates access to a single file.
/// But only if created through a single instance of FileSystem.
/// Creating Files pointing to the same underlying OS file through seperate DeputyFileSystems
/// leads to undefined behaviour.
public actor File {
    let directory: Directory
    let fileSystem: FileSystem
    
    nonisolated
    public let name: String
    
    /// This initialiser is internal. To create a File, first create a Directory with a FileSystem instance and then
    /// create the File with the given Directory object.
    init(directory: Directory, name: String, fileSystem: FileSystem) {
        self.directory = directory
        self.name = name
        self.fileSystem = fileSystem
    }
    
    deinit {
        Task.detached { [fileSystem, name, directory] in
            await fileSystem.deregisterFile(with: name, in: directory)
        }
    }
}

public extension File {
    /// Creates the given file
    func create() async throws {
        try await fileSystem.create(file: self)
    }

    /// Saves the given object as the given file's contents, overriding any existing content
    func save<T: Encodable>(_ object: T) async throws {
        try await fileSystem.save(object, to: self)
    }
    
    /// Saves the given data as the given file's content, overriding any existing content
    func saveData(_ data: Data) async throws {
        try await fileSystem.saveData(data, to: self)
    }
 
    /// Appends the given object to the given file. All objects appended to the same file can be retrieved with
    /// `retrieveAll`
    func append<T: Encodable>(_ object: T) async throws {
        try await fileSystem.append(object, to: self)
    }

    /// Retrieves an object from the given file, assuming the file only contains one such object
    func retrieve<T: Decodable>(as type: T.Type) async throws -> T? {
        try await fileSystem.retrieve(contentsOf: self, as: type)
    }

    /// Retrieves all objects that were appended to the given file
    func retrieveAll<T: Decodable>(as type: T.Type) async throws -> [T] {
        try await fileSystem.retrieveAll(from: self, as: type)
    }

    /// Remove specified file
    func delete() async throws {
        try await fileSystem.remove(self)
    }

    /// Returns a Bool indicating whether the file exists.
    func exists() async -> Bool {
        await fileSystem.exists(self)
    }
    
    /// Returns a URL useful for access the file outside of the FileSystem context.
    /// If you use this URL then you are escaping protections of FileSystem.
    /// Those protections include guarding against writes and reads that could be happening simultanously.
    /// This could lead to unpredicatable and erranoues behaviours.
    func url() async throws -> URL {
        try await fileSystem.fileURLWith(name: name, in: directory)
    }
    
    /// Returns the size of the file in bytes
    func size()  async throws -> Int {
        try await fileSystem.size(of: self)
    }
}
