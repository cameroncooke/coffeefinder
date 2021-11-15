//
//  CoffeeFinderSnapshotTests.swift
//  Copyright © 2021 Cameron Cooke.
//

import XCTest
@testable import CoffeeFinder
import ComposableArchitecture
import SnapshotTesting
import StoreKit
import SwiftUI

class CoffeeFinderSnapshotTests: XCTestCase {

    let scheduler = DispatchQueue.immediate

    // This test intermittently fails because sometimes the snapshot is a earlier or later frame
    // ideally, we would disable animations before taking the snapshot.
    func testLoadingSpinner() {
        let store = Store(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .loading,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }

    func testNoVenueResults() {
        let store = Store(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .empty,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }

    func testVenueResultsDefaultView() {
        let store = Store(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }

    func testVenueResultsMapView() {
        let store = Store(
            initialState: CoffeeFinderState(viewMode: .map),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }

    func testVenueResultsListView() {
        let store = Store(
            initialState: CoffeeFinderState(viewMode: .list),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }

    func testVenueDetails() {

        let venueGroup: VenueGroup = .makeMock()
        let venue = venueGroup.venues[0]
        let venueGroups: [VenueGroup] = [venueGroup]

        let store = Store(
            initialState: CoffeeFinderState(
                location: venue.location,
                showingVenue: venue,
                processState: .loaded(venueGroups)
            ),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)
        let viewController = UIHostingController(rootView: view)

        assertSnapshot(
            matching: viewController,
            as: .windowedImage
        )
    }

    func testFourSquareClientError() {
        let store = Store(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .clientError,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }

    func testFourSquareNetworkError() {
        let store = Store(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .networkError,
                locationClient: .mock,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }

    func testLocationError() {
        let store = Store(
            initialState: CoffeeFinderState(),
            reducer: coffeeFinderReducer,
            environment: CoffeeFinderEnvironment(
                fourSquareClient: .mock,
                locationClient: .error,
                mainQueue: scheduler.eraseToAnyScheduler()
            )
        )

        let view = CoffeeFinderView(store: store)

        assertSnapshot(
            matching: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                layout: .device(config: .iPhoneX)
            )
        )
    }
}

// Custom strategy to snapshot modals taken from:
// https://github.com/pointfreeco/swift-snapshot-testing/issues/279#issuecomment-565445195
//
extension Snapshotting where Value: UIViewController, Format == UIImage {
    static var windowedImage: Snapshotting {
        return Snapshotting<UIImage, UIImage>.image.asyncPullback { viewController in
            Async<UIImage> { callback in
                UIView.setAnimationsEnabled(false)

                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = scene.keyWindow else {
                    fatalError("Unable to find key window, assumes only one UIWindowScene exists")
                }

                window.rootViewController = viewController

                DispatchQueue.main.async {
                    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    callback(image)
                    UIView.setAnimationsEnabled(true)
                }
            }
        }
    }
}
