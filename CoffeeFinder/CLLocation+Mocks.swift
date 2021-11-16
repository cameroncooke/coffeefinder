//
//  CLLocation+Mocks.swift
//  Copyright © 2021 Cameron Cooke.
//

import Foundation
import CoreLocation

extension Collection where Element == CLLocation {
    static func makeMock() -> [CLLocation] {
        return [.makeMock()]
    }
}

extension CLLocation {

    static func makeMock(_ counter: Int = 1) -> CLLocation {
        let lat = 50.830806 * 1 + (Double(counter) / 1000.0)
        let lgn = 0.127818 * 1 + (Double(counter) / 1000.0)
        return CLLocation(latitude: lat, longitude: -lgn)
    }
}

extension CLLocation {
    open override func isEqual(_ object: Any?) -> Bool {
        guard let otherLocation = object as? CLLocation else { return false }
        return self.distance(from: otherLocation) == 0
    }
}
