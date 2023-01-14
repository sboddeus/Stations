
import Foundation

extension OutputStream {
    /// Write Data to file using outputStream
    ///
    /// - parameter data:                  The data to write.
    /// - parameter toFile:                The file path you want to write data to.
    ///
    /// - throws:                          Throws an error if writting to the stream failed
    ///                                    or did not write the expected number of bytes
    static func write(data: Data, toFile filePath: String) throws {
        enum Error: Swift.Error {
            case genericWriteError
            case streamCreationError
        }

        guard let outputStream = OutputStream(toFileAtPath: filePath, append: true) else {
            throw Error.streamCreationError
        }

        outputStream.open()
        defer {
            outputStream.close()
        }

        if outputStream.write(data) < 0 {
            throw outputStream.streamError ?? Error.genericWriteError
        }
    }

    /// Write Data to outputStream
    ///
    /// - parameter data:                  The data to write.
    ///
    /// - returns:                         Return total number of bytes written upon success. Return -1 upon failure.
    func write(_ data: Data) -> Int {
        data.withUnsafeBytes {
            if let bounded = $0.bindMemory(to: UInt8.self).baseAddress {
                return write(bounded, maxLength: data.count)
            } else {
                return -1
            }
        }
    }
}

// Very naughty, but it is ok because the way we use FileManager is thread safe.
// Never to be used outside the scope of FileSystem
final class ABCFileManager: FileManager, @unchecked Sendable {
    static let shared = ABCFileManager()
}
