
import SwiftUI
import ComposableArchitecture
import AVFAudio
import SwiftUINavigation
import SDWebImageSwiftUI

struct Stations: ReducerProtocol {
    struct State: Equatable {
        var stations = ABCStations
        var selectedStation: RadioStation?
        var createStation: CreateStation.State?
        var editStation: EditStation.State?
    }
    
    enum Action: Equatable {
        enum Delegate: Equatable {
            case selected(RadioStation)
        }
        case delegate(Delegate)
        
        // Internal actions
        case selected(RadioStation)
        case showCreateStation(Bool)
        case showEditStation(RadioStation?)
        case onAppear
        case loaded([RadioStation])
        
        // Child Actions
        case createStation(CreateStation.Action)
        case editStation(EditStation.Action)
    }
    
    @Dependency(\.player) var player
    @Dependency(\.stationMaster) var stationMaster
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .showCreateStation(show):
                state.createStation = show ? .init() : nil
                return .none
                
            case let .showEditStation(station):
                if let station {
                    state.editStation = .init(editedStation: station)
                } else {
                    state.editStation = nil
                }
                return .none
                
            case let .selected(station):
                state.selectedStation = station
                return .concatenate(
                    .run { send in
                        AVAudioSession.sharedInstance().activate { _, error in
                            guard error == nil else {
                                // TODO: Deal with error
                                assertionFailure("Couldn't activate session")
                                return
                            }

                            Task {
                                player.play(station)
                                await send(.delegate(.selected(station)))
                            }
                        }
                    }
                )
                
            case .delegate:
                return .none
                
            case .onAppear:
                return .task {
                    let stations = await stationMaster
                        .getStations()
                        .sorted { $0.title < $1.title }
                    
                    return .loaded(stations)
                }
                
            case let .loaded(stations):
                state.stations = stations
                return .none
                
            case .createStation(.delegate(.stationAdded)):
                state.createStation = nil
                return Effect(value: .onAppear)
            
            case .editStation(.delegate(.stationEdited)):
                state.editStation = nil
                return Effect(value: .onAppear)
                
            case .createStation:
                return .none
                
            case .editStation:
                return .none
            }
        }
        .ifLet(\.createStation, action: /Action.createStation) {
            CreateStation()
        }
        .ifLet(\.editStation, action: /Action.editStation) {
            EditStation()
        }
    }
}

struct StationsView: View {
    let store: StoreOf<Stations>
    @ObservedObject var viewStore: ViewStoreOf<Stations>
    
    init(store: StoreOf<Stations>) {
        self.store = store
        viewStore = .init(store, observe: { $0 })
    }
    
    @ViewBuilder
    private func row(station: RadioStation) -> some View {
        Button {
            viewStore.send(.selected(station))
        } label: {
            HStack(alignment: .center) {
                ZStack {
                    Color.white
                    WebImage(url: station.imageURL)
                        .resizable()
                        .padding(2)
                        .scaledToFit()
                }
                .frame(maxWidth: 30, maxHeight: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(station.title)
                    .foregroundColor(viewStore.selectedStation == station ? .red : .white)
                Spacer()
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(viewStore.stations) { station in
                row(station: station)
                    .swipeActions(edge: .trailing) {
                        Button {
                            viewStore.send(.showEditStation(station))
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .tint(.indigo)
                    }
            }
            Button {
                viewStore.send(.showCreateStation(true))
            } label: {
                HStack {
                    Spacer()
                    Text("Add")
                    Spacer()
                }
            }
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.createStation,
                send: { .showCreateStation($0 != nil) }
            )) {
                viewStore.send(.showCreateStation(false))
            } content: { value in
                let store = self.store.scope { _ in
                    value.wrappedValue
                } action: { action in
                    Stations.Action.createStation(action)
                }
                CreateStationView(store: store)
            }
        .fullScreenCover(
            unwrapping: viewStore.binding(
                get: \.editStation,
                send: { .showEditStation($0?.editedStation) }
            )) {
                viewStore.send(.showEditStation(nil))
            } content: { value in
                let store = self.store.scope { _ in
                    value.wrappedValue
                } action: { action in
                    Stations.Action.editStation(action)
                }
                EditStationView(store: store)
            }
    }
}
