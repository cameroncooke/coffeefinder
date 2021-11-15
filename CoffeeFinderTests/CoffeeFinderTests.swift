//
//  CoffeeFinderTests.swift
//  Copyright © 2021 Cameron Cooke.
//

import XCTest
@testable import CoffeeFinder
import ComposableArchitecture
import CoreLocation

class CoffeeFinderTests: XCTestCase {

    let scheduler = DispatchQueue.test

    func testOnAppearHappyPath() {

        let store = TestStore(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        XCTExpectFailure("Assertions below are passing but overall test is being failed by TCA due to an unexpected long-running Effect returned by the `.onAppear` action.")

        store.send(.onAppear) { state in
            state.processState = .loading
            state.location = nil
        }

        scheduler.advance()

        store.receive(.locationClient(.didChangeAuthorisation(.authorizedWhenInUse)))

        scheduler.advance()

        store.receive(.locationClient(.didUpdateLocations(.makeMock()))) { state in
            state.location = .makeMock()
        }

        scheduler.advance()

        store.receive(.venueGroupsResponse(.success(.makeMocks()))) { state in
            state.processState = .loaded(.makeMocks())
        }
    }

    func testOnAppearSadPathLocationClientError() {

        let store = TestStore(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .error,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        XCTExpectFailure("Assertions below are passing but overall test is being failed by TCA due to an unexpected long-running Effect returned by the `.onAppear` action.")

        store.send(.onAppear) { state in
            state.processState = .loading
            state.location = nil
        }

        scheduler.advance()

        store.receive(.locationClient(.didChangeAuthorisation(.authorizedWhenInUse)))

        scheduler.advance()

        store.receive(.locationClient(.didFailWithError(LocationClientMockError()))) { state in
            state.processState = .locationError
        }
    }

    func testOnAppearSadPathFourSquareClientError() {

        let store = TestStore(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .clientError,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        XCTExpectFailure("Assertions below are passing but overall test is being failed by TCA due to an unexpected long-running Effect returned by the `.onAppear` action.")

        store.send(.onAppear) { state in
            state.processState = .loading
            state.location = nil
        }

        scheduler.advance()

        store.receive(.locationClient(.didChangeAuthorisation(.authorizedWhenInUse)))

        scheduler.advance()

        store.receive(.locationClient(.didUpdateLocations(.makeMock()))) { state in
            state.location = .makeMock()
        }

        scheduler.advance()

        store.receive(.venueGroupsResponse(.failure(FourSquareClient.Error.clientError))) { state in
            state.processState = .fetchError(.clientError)
        }
    }

    func testViewModeChanged() {

        let store = TestStore(
            initialState: CoffeeFinderState(
                viewMode: .list
            ),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        store.send(.viewModeChanged(.map)) { state in
            state.viewMode = .map
        }
    }

    func testShowVenueDetails() {
        let store = TestStore(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        store.send(.showVenueDetails(.makeMock(1))) { state in
            state.showingVenue = .makeMock(1)
        }
    }

    func testDismissVenueDetails() {
        let store = TestStore(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        store.send(.dismissVenueDetails) { state in
            state.showingVenue = nil
        }
    }

}
