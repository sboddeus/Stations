//
//  DEBUG.swift
//  Leincast Watch App
//
//  Created by Sye Boddeus on 28/1/2023.
//

import Foundation

import Foundation
import SwiftUI

@Observable class FileSizeForDisplay {
    var fileSize: String?

    func calculateStorage() {
        Task {
            let fs = FileSystem.default
            let docDir = fs.directory(inBase: .documents, path: URL(string: "/")!)
            let cacheDir = fs.directory(inBase: .caches, path: URL(string: "/")!)
            if let docSize = try? await docDir.size(),
               let cacheSize = try? await cacheDir.size() {
                fileSize = "Storage Used: \(ByteCountFormatter.string(fromByteCount: Int64(docSize + cacheSize), countStyle: .decimal))"
            }

        }
    }
}

public struct DEBUG: View {
    @State var fileSize = FileSizeForDisplay()
    
    func bootTime() -> Date? {
        var tv = timeval()
        var tvSize = MemoryLayout<timeval>.size
        let err = sysctlbyname("kern.boottime", &tv, &tvSize, nil, 0);
        guard err == 0, tvSize == MemoryLayout<timeval>.size else {
            return nil
        }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000.0)
    }

    private static let intervalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        return formatter
    }()
    
    func interval(toDate: Date) -> DateInterval {
        DateInterval(start: bootTime() ?? toDate, end: toDate)
    }
    
    public var body: some View {
        VStack {
            TimelineView(.everyMinute) { context in
                Text("Uptime: " + (Self.intervalFormatter.string(from: interval(toDate: context.date).duration) ?? ""))
                    .minimumScaleFactor(0.7)
            }
            if let size = fileSize.fileSize {
                Text(size)
                    .minimumScaleFactor(0.7)
            }
        }
        .onAppear {
            fileSize.calculateStorage()
        }
    }
}
