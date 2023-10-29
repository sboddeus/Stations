
import SwiftUI
import ComposableArchitecture

struct Help: Reducer {
    struct State: Equatable {
        
    }
    
    enum Action: Equatable {
        
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}

struct HelpView: View {
    let store: StoreOf<Help>
    @ObservedObject var viewStore: ViewStoreOf<Help>
    
    init(store: StoreOf<Help>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Adding streams")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("HLS Streams")
                        .font(.title3)
                        .foregroundColor(LeincastColors.brand.color)
                    Divider()
                    Text("""
                    HLS is a streaming format used to broadcast audio from service providers to your watch.
                    One way to tell if a URL points to a HLS stream is if it ends in the suffix "m3u8".
                    You can search online for "m3u8" streams or "HLS" streams to find if your prefered streaming service or radio broadcast is available as a HLS stream.
                    """)
                    
                    Text("Stream Icons")
                        .font(.title3)
                        .foregroundColor(LeincastColors.brand.color)
                    Divider()
                    Text("""
                    When creating or editing a stream, you can add a link to an icon that will appear in parts of the UI.
                    For best results, make sure the linked image is of PNG, or JPEG formats.
                    """)
                }
            }
        }
    }
}

