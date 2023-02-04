
import Foundation

actor ClipBoard {
    
    private var filesystem: FileSystem = .default
    private var rootPath = URL(string: "/CopyCache")!
    
    private var rootDirectory: Directory {
        filesystem.directory(
            inBase: .caches,
            path: rootPath
        )
    }
    
    enum ContentType: Equatable {
        case stream(Stream)
        case directory(Directory)
    }
    private var _content: [ContentType] = []

    func add(stream: Stream) {
        _content.append(.stream(stream))
    }
    
    func add(directory: Directory) async {
        // First move into a temp directory
        if let dir = try? await directory.move(into: rootDirectory) {
            // Then add to clipboard
            _content.append(.directory(dir))
        }
    }
    
    func content() -> [ContentType] {
        _content
    }
    
    func remove(content: ContentType) {
        _content = _content.filter { $0 != content }
    }
}
