//
//  CoffeeFinderView.swift
//  Copyright © 2021 Cameron Cooke.
//

import SwiftUI
import ComposableArchitecture
import CoreLocation
import MapKit

// MARK: - TCA -

private struct LocationClientId: Hashable {}
private struct FourSquareClientId: Hashable {}

enum ViewMode: LocalizedStringKey, CaseIterable, Equatable {
    case map = "Map"
    case list = "List"
}

enum ProcessState: Equatable {
    case loading
    case loaded ([VenueGroup])
    case fetchError(FourSquareClient.Error)
    case locationError
}

extension FourSquareClient.Error {
    var errorDescription: String {
        switch self {
        case .clientError:
            return "So sorry, there was an error and it's on us"
        case .networkError:
            return "We've been unable to find venues due to a network issue, please check your internet connection"
        }
    }
}

struct CoffeeFinderState: Equatable {
    var viewMode: ViewMode = .list
    var location: CLLocation?
    var showingVenue: Venue?
    var processState: ProcessState = .loading
}

enum CoffeeFinderAction: Equatable {
    case locationClient(LocationClient.DelegateEvent)
    case venueGroupsResponse(Result<[VenueGroup], FourSquareClient.Error>)
    case viewModeChanged(ViewMode)
    case showVenueDetails(Venue)
    case dismissVenueDetails
    case onAppear
    case onDisappear
}

struct CoffeeFinderEnvironment {
    var fourSquareClient: FourSquareClient
    var locationClient: LocationClient
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

let coffeeFinderReducer = Reducer<CoffeeFinderState, CoffeeFinderAction, CoffeeFinderEnvironment> { state, action, environment in

    switch action {
    case .onAppear:
        return .merge(
            environment.locationClient.delegate()
                .map(CoffeeFinderAction.locationClient)
                .cancellable(id: LocationClientId()),
            environment.locationClient
                .requestWhenInUseAuthorisation()
                .fireAndForget()
        )

    case .onDisappear:
        return .cancel(id: LocationClientId())

    case .locationClient(let event):

        switch event {
        case .didChangeAuthorisation(let status):
            return environment.locationClient.requestLocation().fireAndForget()

        case .didUpdateLocations(let locations):
            let nearestLocation = locations[0]
            state.location = nearestLocation

            return environment.fourSquareClient
                .searchVenues(
                    nearestLocation.coordinate.longitude.formatted(),
                    nearestLocation.coordinate.latitude.formatted()
                )
                .receive(on: environment.mainQueue)
                .catchToEffect(CoffeeFinderAction.venueGroupsResponse)
                .cancellable(id: FourSquareClientId())

        case .didFailWithError(let error):
            state.processState = .locationError
        }

        return .none

    case .venueGroupsResponse(.success(let venueGroups)):
        state.processState = .loaded(venueGroups)
        return .none

    case .venueGroupsResponse(.failure(let error)):
        state.processState = .fetchError(error)
        return .none

    case .viewModeChanged(let viewMode):
        state.viewMode = viewMode
        return .none

    case .showVenueDetails(let venue):
        state.showingVenue = venue
        return .none

    case .dismissVenueDetails:
        state.showingVenue = nil
        return .none
    }
}

// MARK: - Views -

struct CoffeeFinderView: View {
    let store: Store<CoffeeFinderState, CoffeeFinderAction>

    var body: some View {
        NavigationView {

            WithViewStore(self.store) { viewStore in

                switch viewStore.processState {
                case .loading:
                    ProgressView()
                        .onAppear(perform: { viewStore.send(.onAppear) })
                        .onDisappear(perform: { viewStore.send(.onDisappear) })
                        .edgesIgnoringSafeArea(.all)

                case .loaded(let venueGroups):

                    if venueGroups.isEmpty {
                        ErrorText("So sorry, there were no venues near your location")

                    } else {
                        ZStack {

                            VenueMap(
                                venues: venueGroups.flatMap { $0.venues },
                                centerCoordinate: viewStore.location!.coordinate
                            ) { venue in
                                viewStore.send(.showVenueDetails(venue))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)

                            VenueList(viewStore: viewStore, venueGroups: venueGroups)
                                .background(.ultraThinMaterial)
                                .safeAreaInset(edge: .top, content: {
                                    Spacer()
                                        .frame(maxHeight: 60)
                                })
                                .opacity(viewStore.viewMode == .list ? 1 : 0)
                        }
                        .overlay(
                            VStack {
                                PickerBar(viewStore: viewStore)
                                Spacer()
                            }
                        )
                        .sheet(
                            isPresented: .constant(viewStore.showingVenue != nil),
                            onDismiss: {
                                viewStore.send(.dismissVenueDetails)
                            }
                        ) {
                            VenueDetails(viewStore: viewStore, venue: viewStore.showingVenue!)
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarHidden(true)
                    }

                case .fetchError(let error):
                    ErrorText(error.errorDescription)

                case .locationError:
                    ErrorText("So sorry, we couldn't identify your location")
                }
            }
        }
    }
}

struct ErrorText: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.body)
            .multilineTextAlignment(.center)
            .padding()
    }
}

struct PickerBar: View {

    let viewStore: ViewStore<CoffeeFinderState, CoffeeFinderAction>

    var body: some View {
        Picker(
            "View mode",
            selection: viewStore.binding(
                get: \.viewMode,
                send: CoffeeFinderAction.viewModeChanged
            )
        ) {
            ForEach(ViewMode.allCases, id: \.self) { viewMode in
                Text(viewMode.rawValue).tag(viewMode)
            }
        }
        .pickerStyle(.segmented)
        .padding([.leading, .trailing, .bottom], 20)
        .background(.ultraThinMaterial)
    }
}

struct VenueDetails: View {

    let viewStore: ViewStore<CoffeeFinderState, CoffeeFinderAction>
    let venue: Venue

    var body: some View {
        List {
            Section {
                Text(venue.name)
                    .font(.headline)
            } header: {}

            Section {
                let addressFields = [
                    venue.address.address,
                    venue.address.city,
                    venue.address.state,
                    venue.address.postalCode
                ].compactMap { $0 }

                ForEach(addressFields, id: \.self) { field in
                    Text(field)
                }

            } header: {
                Text("Address")
            }

            Section {

                VenueMap(
                    venues: [venue],
                    centerCoordinate: venue.location.coordinate,
                    tapGesture: { _ in }
                )
                    .allowsHitTesting(false)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets.init(top: 0, leading: 0, bottom: 0, trailing: 0))

            } header: {}

            Button {
                viewStore.send(.dismissVenueDetails)
            } label: {
                Text("Dismiss")
                    .bold()
                    .frame(maxWidth: .infinity, maxHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .background(Material.ultraThinMaterial)
    }
}

struct VenueMap: View {

    struct PinAnnotationView: View {
        var body: some View {
            Image(systemName: "mappin")
                .font(.title)
                .foregroundColor(.red)
        }
    }

    let venues: [Venue]
    let centerCoordinate: CLLocationCoordinate2D
    let tapGesture: (Venue) -> Void

    var body: some View {
        Map(
            coordinateRegion: .constant(
                MKCoordinateRegion(
                    center: centerCoordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: 0.02,
                        longitudeDelta: 0.02
                    )
                )
            ),
            showsUserLocation: true, userTrackingMode: .none, annotationItems: venues
        ) { venue in
            MapAnnotation(coordinate: venue.location.coordinate, anchorPoint: CGPoint(x: 0.5, y: 1)) {
                PinAnnotationView()
                    .onTapGesture {
                        tapGesture(venue)
                    }
            }
        }
    }
}

struct VenueList: View {

    let viewStore: ViewStore<CoffeeFinderState, CoffeeFinderAction>
    let venueGroups: [VenueGroup]

    var body: some View {
        List {
            ForEach(venueGroups, id: \.self) { venueGroup in
                Section {
                    ForEach(venueGroup.venues, id: \.id) { venue in

                        Button {
                            viewStore.send(.showVenueDetails(venue))
                        } label: {
                            Text(venue.name)
                        }
                        .listRowBackground(Color.white.opacity(0.6))

                    }
                } header: {
                    Text(venueGroup.name.capitalized)
                }
            }
        }
    }
}

struct CoffeeFinderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CoffeeFinderView(
                store: Store(
                    initialState: CoffeeFinderState(),
                    reducer: coffeeFinderReducer,
                    environment: CoffeeFinderEnvironment(
                        fourSquareClient: .mock,
                        locationClient: .mock,
                        mainQueue: .main
                    )
                )
            )
            CoffeeFinderView(
                store: Store(
                    initialState: CoffeeFinderState(showingVenue: .makeMock(1)),
                    reducer: coffeeFinderReducer,
                    environment: CoffeeFinderEnvironment(
                        fourSquareClient: .mock,
                        locationClient: .mock,
                        mainQueue: .main
                    )
                )
            )
            CoffeeFinderView(
                store: Store(
                    initialState: CoffeeFinderState(viewMode: .map),
                    reducer: coffeeFinderReducer,
                    environment: CoffeeFinderEnvironment(
                        fourSquareClient: .mock,
                        locationClient: .mock,
                        mainQueue: .main
                    )
                )
            )
            CoffeeFinderView(
                store: Store(
                    initialState: CoffeeFinderState(),
                    reducer: coffeeFinderReducer,
                    environment: CoffeeFinderEnvironment(
                        fourSquareClient: .empty,
                        locationClient: .mock,
                        mainQueue: .main
                    )
                )
            )

            Group {
                CoffeeFinderView(
                    store: Store(
                        initialState: CoffeeFinderState(),
                        reducer: coffeeFinderReducer,
                        environment: CoffeeFinderEnvironment(
                            fourSquareClient: .networkError,
                            locationClient: .mock,
                            mainQueue: .main
                        )
                    )
                )
                CoffeeFinderView(
                    store: Store(
                        initialState: CoffeeFinderState(),
                        reducer: coffeeFinderReducer,
                        environment: CoffeeFinderEnvironment(
                            fourSquareClient: .clientError,
                            locationClient: .mock,
                            mainQueue: .main
                        )
                    )
                )
                CoffeeFinderView(
                    store: Store(
                        initialState: CoffeeFinderState(),
                        reducer: coffeeFinderReducer,
                        environment: CoffeeFinderEnvironment(
                            fourSquareClient: .mock,
                            locationClient: .error,
                            mainQueue: .main
                        )
                    )
                )
                CoffeeFinderView(
                    store: Store(
                        initialState: CoffeeFinderState(),
                        reducer: coffeeFinderReducer,
                        environment: CoffeeFinderEnvironment(
                            fourSquareClient: .mock,
                            locationClient: .loading,
                            mainQueue: .main
                        )
                    )
                )
            }
        }
    }
}
