
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

