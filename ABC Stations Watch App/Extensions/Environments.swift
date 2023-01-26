//
//  Environments.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 27/1/2023.
//

import SwiftUI

enum PresentationContext: Equatable {
    case fullScreen
    case embedded
}
private struct PresentationContextKey: EnvironmentKey {
    static let defaultValue: PresentationContext = .embedded
}

extension EnvironmentValues {
    var presentationContext: PresentationContext {
        get { self[PresentationContextKey.self] }
        set { self[PresentationContextKey.self] = newValue }
    }
}

