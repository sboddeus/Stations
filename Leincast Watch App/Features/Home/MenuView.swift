
import Foundation
import SwiftUI
import ComposableArchitecture

struct Menu: Reducer {
    struct State: Equatable {
        enum Route: Equatable {
            case debug
        }
        var route: Route?
    }
    
    enum Action: Equatable {
        case setRoute(State.Route?)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setRoute(route):
                state.route = route
                return .none
            }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    viewStore.send(.setRoute(.debug))
                } label: {
                    Text("Debug")
                }
                
                Text("Version: \(Bundle.main.combinedVersionString)")
            }
        }.navigationDestination(
            isPresented: viewStore.binding(
                get: { state in
                    state.route == .debug
                }, send: { value in
                    .setRoute(value ? .debug : nil)
                }), destination: {
                    DEBUG()
                })
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
