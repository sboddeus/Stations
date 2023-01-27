//
//  DEBUG.swift
//  Leincast Watch App
//
//  Created by Sye Boddeus on 28/1/2023.
//

import Foundation

import Foundation
import SwiftUI

public struct DEBUG: View {
    
    public init() {}
    
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
        TimelineView(.everyMinute) { context in
            Text("Uptime: " + (Self.intervalFormatter.string(from: interval(toDate: context.date).duration) ?? ""))
                .minimumScaleFactor(0.7)
        }
    }
}
