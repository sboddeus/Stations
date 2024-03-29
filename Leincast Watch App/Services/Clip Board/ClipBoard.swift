
import Foundation

actor ClipBoard {
    
    private var filesystem: FileSystem = .default
    private var rootPath = URL(string: "CopyCache")!
    
    private var rootDirectory: Directory {
        filesystem.directory(
            inBase: .caches,
            path: rootPath
        )
    }
    
    enum ContentType: Equatable, Identifiable {
        case stream(Stream)
        case directory(Directory)

        var id: String {
            switch self {
            case let .stream(stream):
                return stream.id
            case let .directory(dir):
                return dir.path.absoluteString
            }
        }
    }
    private var _content: [ContentType] = []

    func add(stream: Stream) {
        _content.append(.stream(stream))
    }
    
    func add(directory: Directory) async throws {
        // First move into a temp directory
        let dir = try await directory.move(into: rootDirectory)

        // Then add to clipboard
        _content.append(.directory(dir))
    }
    
    func content() -> [ContentType] {
        _content
    }
    
    func remove(content: ContentType) {
        _content = _content.filter { $0 != content }
    }

    func initialise() async {
        try? await rootDirectory.create()
        let dirs = (try? await rootDirectory.retrieveAllSubDirectories()) ?? []
        for dir in dirs {
            try? await dir.remove()
        }
    }
}
