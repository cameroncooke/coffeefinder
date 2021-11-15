//
//  LocationClient.swift
//  Copyright © 2021 Cameron Cooke.
//

import Foundation
import ComposableArchitecture
import Combine
import CoreLocation

// MARK: - Interface -

struct LocationClient {
    var requestWhenInUseAuthorisation: () -> Effect<Never, Never>
    var requestLocation: () -> Effect<Never, Never>
    var delegate: () -> Effect<DelegateEvent, Never>

    enum DelegateEvent: Equatable {
        case didChangeAuthorisation(CLAuthorizationStatus)
        case didUpdateLocations([CLLocation])
        case didFailWithError(Error)
    }
}

extension LocationClient.DelegateEvent {
    static func == (lhs: LocationClient.DelegateEvent, rhs: LocationClient.DelegateEvent) -> Bool {
        switch (lhs, rhs) {
        case (.didChangeAuthorisation, .didChangeAuthorisation): return true
        case (.didUpdateLocations, .didUpdateLocations): return true
        case (.didFailWithError, .didFailWithError): return true
        default: return false
        }
    }
}

// MARK: - Live Client -

extension LocationClient {

    static var live: Self {

        class Delegate: NSObject, CLLocationManagerDelegate {

            let subscriber: Effect<DelegateEvent, Never>.Subscriber

            init(_ subscriber: Effect<DelegateEvent, Never>.Subscriber) {
              self.subscriber = subscriber
            }

            func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
                self.subscriber.send(.didChangeAuthorisation(manager.authorizationStatus))
            }

            func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
                self.subscriber.send(.didFailWithError(error))
            }

            func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
                self.subscriber.send(.didUpdateLocations(locations))
            }
        }

        let locationManager = CLLocationManager()

        let delegate = Effect<DelegateEvent, Never>.run { subscriber in
            let delegate = Delegate(subscriber)
            locationManager.delegate = delegate

            return AnyCancellable {
                _ = delegate
            }
        }
        .share()
        .eraseToEffect()

        return Self(
            requestWhenInUseAuthorisation: { .fireAndForget { locationManager.requestWhenInUseAuthorization() } },
            requestLocation: { .fireAndForget { locationManager.requestLocation() } },
            delegate: { delegate }
        )
    }
}

// MARK: - Mock -

extension LocationClient {

    static var mock: Self {

        let delegateSubject = PassthroughSubject<DelegateEvent, Never>()

        return Self(
            requestWhenInUseAuthorisation: { .fireAndForget { delegateSubject.send(.didChangeAuthorisation(.authorizedWhenInUse)) } },
            requestLocation: { .fireAndForget { delegateSubject.send(.didUpdateLocations(.makeMock())) } },
            delegate: {
                delegateSubject.eraseToEffect()
            }
        )
    }

    static var loading: Self {

        return Self(
            requestWhenInUseAuthorisation: { .fireAndForget {  } },
            requestLocation: { .fireAndForget {  } },
            delegate: { .fireAndForget {  } }
        )
    }

    static var error: Self {

        let delegateSubject = PassthroughSubject<DelegateEvent, Never>()

        return Self(
            requestWhenInUseAuthorisation: { .fireAndForget { delegateSubject.send(.didChangeAuthorisation(.authorizedWhenInUse)) } },
            requestLocation: { .fireAndForget { delegateSubject.send(.didFailWithError(LocationClientMockError())) } },
            delegate: {
                delegateSubject.eraseToEffect()
            }
        )
    }
}

struct LocationClientMockError: Error {
    var errorDescription = "Location services error"
}
