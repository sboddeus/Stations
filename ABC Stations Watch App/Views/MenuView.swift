
import Foundation
import SwiftUI
import ComposableArchitecture

struct Menu: ReducerProtocol {
    struct State: Equatable {
        
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case tappedNowPlaying
            case tappedDebugMenu
        }
        case delegate(Delegate)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}

struct MenuView: View {
    let store: StoreOf<Menu>
    @ObservedObject var viewStore: ViewStoreOf<Menu>
    
    init(store: StoreOf<Menu>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        List {
            Button {
                viewStore.send(.delegate(.tappedNowPlaying))
            } label: {
                Text("Now Playing")
            }
            
            Button {
                viewStore.send(.delegate(.tappedDebugMenu))
            } label: {
                Text("Debug")
            }
            
            Text("Version: \(Bundle.main.combinedVersionString)")
        }
    }
}

// MARK: Helpers

extension Bundle {
    var releaseVersionNumber: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    var buildVersionNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    var combinedVersionString: String {
        return "\(releaseVersionNumber) (\(buildVersionNumber))"
    }
}
