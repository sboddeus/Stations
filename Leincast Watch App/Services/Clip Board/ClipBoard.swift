
import Foundation

actor ClipBoard {
    private var _content: [Stream] = []

    func add(stream: Stream) {
        _content.append(stream)
    }
    
    func content() -> [Stream] {
        _content
    }
    
    func remove(stream: Stream) {
        _content = _content.filter { $0 != stream }
    }
}
