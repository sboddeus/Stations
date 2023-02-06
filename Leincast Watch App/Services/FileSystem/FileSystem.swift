
import Foundation

// This actor coordinates access to files and directories.
// Most applications should only have one instance of this actor in use at any given time.
// To make this convienient there is the 'default' instance that can be accessed.
public actor FileSystem {


    enum FileSystemError: Error {
        case corruptURL
    }
    
    /// The default instance of a DeputyFileSystem to use within an app.
    public static var `default` = FileSystem()
    
    private let fileManager: ABCFileManager
    private var fileRegistry = [URL: File]()
    
    /// Create a managed file system using a Foundation FileManager.
    /// In general, you should create one FileSystem per app instance.
    /// For convienience there is a static `default` available
    public init() {
        self.fileManager = ABCFileManager.shared
    }
    
    /// Returns a `Directory` managed by this instance of the `FileSystem`
    /// Expects a path without the root component and without a host prefix.
    public nonisolated func directory(absolutePath: String) -> Directory? {
        guard let url = URL(string: absolutePath) else { return nil }
        return Directory(baseDirectory: .root, path: url, fileSystem: self)
    }
    
    /// Returns a `Directory` managed by this instance of the `FileSystem`
    public nonisolated func directory(in directory: Directory, path: URL) -> Directory {
        return Directory(baseDirectory: .directory(directory), path: path, fileSystem: self)
    }
    
    /// Returns a `Directory` managed by this instance of the `FileSystem`
    public nonisolated func directory(inBase directory: Directory.BaseDirectory, path: URL) -> Directory {
        return Directory(baseDirectory: directory, path: path, fileSystem: self)
    }
    
    /// Creates a file from the given URL.
    /// This is helpful for converting URLs from system APIs to a Deputy File System File representation.
    public nonisolated func file(fromPath path: URL) async throws -> File? {
        let isFilePrefix = "file:///"
        guard path.absoluteString.hasPrefix(isFilePrefix) else {
            return nil
        }
        
        let fileName: String = path.lastPathComponent
        // We just want a path without the file prefix and without the file name to create a directory.
        let directoryPath = path.pathComponents
            .dropFirst(1)
            .dropLast(1)
            .joined(separator: "/")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)

        guard
            let path = directoryPath,
            let directory = directory(absolutePath: path) else {
            return nil
        }
        
        return try await directory.file(name: fileName)
    }
}

// Internal implementation details for managing Files and Directories
extension FileSystem {
    // Creates the given file
    nonisolated func create(file: File) async throws {
        try await fileManager.createDirectory(at: file.directory.url(fileManager: fileManager),
                                              withIntermediateDirectories: true,
                                              attributes: nil)
        let url = try await fileURLWith(name: file.name, in: file.directory)
        fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
    }

    // Creates the given directory
    nonisolated func create(directory: Directory) async throws {
        try await fileManager.createDirectory(at: directory.url(fileManager: fileManager),
                                              withIntermediateDirectories: true)
    }

    // Saves the given object as the given file's contents, overriding any existing content
    nonisolated func save<T: Encodable>(_ object: T, to file: File) async throws {
        let data = try JSONEncoder().encode(object)
        try await saveData(data, to: file)
    }

    nonisolated func saveData(_ data: Data, to file: File) async throws {
        let url = try await fileURLWith(name: file.name, in: file.directory)
        if fileManager.fileExists(atPath: url.path) {
            try await remove(file)
        }
        try await create(file: file)
        
        await Task.yield()
        
        // We make use of an OutputStream so that we can better handle writing errors.
        // At this time, FileHandle.write is deprecated and throws Objective-C Exceptions.
        try OutputStream.write(data: data, toFile: url.path)
    }
    
    // Appends the given object to the given file. All objects appended to a same file can be retrieved with
    // `retrieveAll`
    nonisolated func append<T: Encodable>(_ object: T, to file: File) async throws {
        let url = try await fileURLWith(name: file.name, in: file.directory)
        var newFile = false
        if !fileManager.fileExists(atPath: url.path) {
            try await create(file: file)
            newFile = true
        }

        let data = try JSONEncoder().encode(object)

        var dataToWrite = data
        if !newFile,
            let append = "\n".data(using: .utf8) {
            dataToWrite = append + data
        }

        await Task.yield()
        
        // We make use of an OutputStream so that we can better handle writing errors.
        // At this time, FileHandle.write is deprecated and throws Objective-C Exceptions.
        try OutputStream.write(data: dataToWrite, toFile: url.path)
    }

    // Retrieves an object from the given file, assuming the file only contains one such object
    nonisolated func retrieve<T: Decodable>(contentsOf file: File, as type: T.Type) async throws -> T? {
        let url = try await fileURLWith(name: file.name, in: file.directory)

        if !fileManager.fileExists(atPath: url.path) {
            return nil
        }
        guard let data = try? String(contentsOfFile: url.path, encoding: .utf8).data(using: .utf8) else {
            return nil
        }

        let thing = try JSONDecoder().decode(type, from: data)
        return thing
    }

    // Retrieves all objects that were appended to the given file
    nonisolated func retrieveAll<T: Decodable>(from file: File, as type: T.Type) async throws -> [T] {
        let url = try await fileURLWith(name: file.name, in: file.directory)

        if !fileManager.fileExists(atPath: url.path) {
            return [T]()
        }
        guard let string = try? String(contentsOfFile: url.path, encoding: .utf8) else {
            return [T]()
        }

        return try string.components(separatedBy: .newlines)
            .compactMap { $0.data(using: .utf8) }
            .map { try JSONDecoder().decode(type, from: $0) }
    }

    // Retrieve all files from the the given direcory
    nonisolated func retrieveAllFiles(from directory: Directory) async throws -> [File] {
        let url = try await directory.url(fileManager: fileManager)

        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        
        var results = [File]()
        for content in contents {
            if let file = try? await self.file(directory: directory, name: content.lastPathComponent),
               await exists(file) {
                results.append(file)
            }
        }
        
        return results
    }

    // Retrieve all subdirectories in the given directory
    nonisolated func retrieveAllSubDirectories(from directory: Directory) async throws -> [Directory] {
        let url = try await directory.url(fileManager: fileManager)

        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: []
        )
        
        var results = [Directory]()
        for content in contents {
            guard let pathComponent = content
                .lastPathComponent
                .addingPercentEncoding(
                    withAllowedCharacters: .urlPathAllowed
                ),
                let path = URL(string: pathComponent) else {
                continue
            }
            let directory = await directory.directory(path: path)
             if await exists(directory) {
                results.append(directory)
            }
        }
        return results
    }

    /// Remove specified file
    nonisolated func remove(_ file: File) async throws {
        let url = try await fileURLWith(name: file.name, in: file.directory)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Remove all files at specified directory including the directory itself
    nonisolated func remove(_ directory: Directory) async throws {
        let url = try await directory.url(fileManager: fileManager)

        try fileManager.removeItem(at: url)
    }
    
    /// Renames a given directory to the given name
    nonisolated func rename(directory: Directory, to: String) async throws -> Directory {
        let original = try await directory.url(fileManager: fileManager)
        let new = original
            .deletingLastPathComponent()
            .appending(path: to)
        
        try fileManager.moveItem(at: original, to: new)
        
        return Directory(
            baseDirectory: directory.baseDirectory,
            path: new,
            fileSystem: self
        )
    }
    
    nonisolated func move(directory: Directory, into: Directory) async throws -> Directory {
        let original = try await directory.url(fileManager: fileManager)
        let intoURL = try await into.url(fileManager: fileManager).appending(component: directory.name)
        try fileManager.moveItem(at: original, to: intoURL)
        guard let directoryName = directory.name
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let directoryNameURL = URL(string: directoryName) else {
            throw FileSystemError.corruptURL
        }
        return await into.directory(path: directoryNameURL)
    }

    nonisolated func duplicate(directory: Directory) async throws -> Directory {
        let original = try await directory.url(fileManager: fileManager)
        let newName = (directory.name + " (copy)")
            let intoURL = original.deletingLastPathComponent().appending(path: newName)
            try fileManager.copyItem(at: original, to: intoURL)
            return Directory(baseDirectory: directory.baseDirectory, path: intoURL, fileSystem: directory.fileSystem)
    }

    // Returns BOOL indicating whether the file exists
    nonisolated func exists(_ file: File) async -> Bool {
        do {
            let url = try await fileURLWith(name: file.name, in: file.directory)
            var isDir: ObjCBool = false
            let somethingExists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
            return somethingExists && !isDir.boolValue
        } catch {
            return false
        }
    }

    // Returns BOOL indicating if the given directory exists
    nonisolated func exists(_ directory: Directory) async -> Bool {
        do {
            let url = try await directory.url(fileManager: fileManager)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
            return isDir.boolValue
        } catch {
            return false
        }
    }
    
    func deregisterFile(with name: String, in directory: Directory) async {
        if let url = try? await fileURLWith(name: name, in: directory) {
            fileRegistry.removeValue(forKey: url)
        }
    }
    
    func file(directory: Directory, name: String) async throws -> File {
        let newFile = File(directory: directory, name: name, fileSystem: self)
        let url = try await fileURLWith(name: newFile.name, in: newFile.directory)
        if let existing = fileRegistry[url] {
            return existing
        } else {
            fileRegistry[url] = newFile
            return newFile
        }
    }
    
    nonisolated func fileURLWith(name: String, in directory: Directory) async throws -> URL {
        try await directory.url(fileManager: fileManager).appendingPathComponent(name)
    }
    
    nonisolated func size(of file: File) async throws -> Int {
        
        let path = try await file.url()
        
        let attributes = try path.resourceValues(forKeys: [.fileSizeKey])
        
        let fileSize = attributes.fileSize
        
        return fileSize ?? 0
    }
}
