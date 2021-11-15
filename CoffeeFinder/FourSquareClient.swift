//
//  FourSquareClient.swift
//  Copyright © 2021 Cameron Cooke.
//

import Foundation
import ComposableArchitecture
import Combine
import CoreLocation

// MARK: - Data -

struct Venue: Hashable, Decodable, Identifiable {

    struct Address: Hashable, Decodable {
        let address: String?
        let city: String?
        let state: String?
        let postalCode: String?
    }

    let id: String
    let name: String
    let location: CLLocation
    let address: Address

    init(id: String, name: String, location: CLLocation, address: Address) {
        self.id = id
        self.name = name
        self.location = location
        self.address = address
    }

    enum CodingKeys: String, CodingKey {
        case name
        case venue
        case id
        case location
        case lat
        case lng
        case address
        case city
        case state
        case postalCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let venueContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .venue)
        let locationContainer = try venueContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .location)

        self.id = try venueContainer.decode(String.self, forKey: .id)
        self.name = try venueContainer.decode(String.self, forKey: .name)

        let lat = try locationContainer.decode(CLLocationDegrees.self, forKey: .lat)
        let lng = try locationContainer.decode(CLLocationDegrees.self, forKey: .lng)
        self.location = CLLocation(latitude: lat, longitude: lng)

        self.address = Address(
            address: try locationContainer.decodeIfPresent(String.self, forKey: .address),
            city: try locationContainer.decodeIfPresent(String.self, forKey: .city),
            state: try locationContainer.decodeIfPresent(String.self, forKey: .state),
            postalCode: try locationContainer.decodeIfPresent(String.self, forKey: .postalCode)
        )
    }
}

struct VenueGroup: Hashable, Decodable {

    let name: String
    let venues: [Venue]

    init(name: String, venues: [Venue]) {
        self.name = name
        self.venues = venues
    }

    enum CodingKeys: String, CodingKey {
        case name
        case items
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.venues = try container.decode([Venue].self, forKey: .items)
    }
}

struct VenueResponse: Hashable, Decodable {
    let venueGroups: [VenueGroup]

    init(venueGroups: [VenueGroup]) {
        self.venueGroups = venueGroups
    }

    enum CodingKeys: String, CodingKey {
        case response
        case groups
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let responseContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .response)

        self.venueGroups = try responseContainer.decode([VenueGroup].self, forKey: .groups)
    }
}

// MARK: - Interface -

struct FourSquareClient {
    typealias Longitude = String
    typealias Latitude = String

    var searchVenues: (Longitude, Latitude) -> Effect<[VenueGroup], Error>

    enum Error: Swift.Error, Equatable {
        case clientError
        case networkError
    }
}

// MARK: - Live Client -

extension FourSquareClient {

    static func live(urlSession: URLSession = .shared)  ->  Self {
        return Self(
            searchVenues: { lat, long in

                guard var components = URLComponents(string: "https://api.foursquare.com/v2/venues/explore") else {
                    return Fail(error: .clientError)
                        .eraseToEffect()
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd"

                components.queryItems = [
                    URLQueryItem(name: "client_id", value: Constants.FourSquare.clientId),
                    URLQueryItem(name: "client_secret", value: Constants.FourSquare.secretId),
                    URLQueryItem(name: "section", value: Constants.FourSquare.section),
                    URLQueryItem(name: "v", value: dateFormatter.string(from: Date.now)),
                    URLQueryItem(name: "ll", value: "\(long),\(lat)")
                ]

                guard let url = components.url else {
                    return Fail(error: .clientError)
                        .eraseToEffect()
                }

                return urlSession.dataTaskPublisher(for: url)
                    .map { $0.data }
                    .decode(type: VenueResponse.self, decoder: JSONDecoder())
                    .map { $0.venueGroups }
                    .mapError { _ in FourSquareClient.Error.networkError }
                    .eraseToEffect()
            }
        )
    }
}

// MARK: - Mock Client -

extension FourSquareClient {

    static let mock = Self(
        searchVenues: { _,_ in
            return Just(.makeMocks())
                .setFailureType(to: Error.self)
                .eraseToEffect()
        }
    )

    static let empty = Self(
        searchVenues: { _,_ in
            return Just([])
                .setFailureType(to: Error.self)
                .eraseToEffect()
        }
    )

    static let clientError = Self(
        searchVenues: { _,_ in
            return Fail(error: FourSquareClient.Error.clientError)
                .eraseToEffect()
        }
    )

    static let networkError = Self(
        searchVenues: { _,_ in
            return Fail(error: FourSquareClient.Error.networkError)
                .eraseToEffect()
        }
    )
}

// MARK: - Mock Data -

extension Venue {
    static func makeMock(_ mockCounter: Int) -> Venue {
        Self(
            id: String(mockCounter),
            name: "Cool Coffee",
            location: .makeMock(mockCounter),
            address: Address(
                address: "44 Cool Street",
                city: "Cool City",
                state: "Cool State",
                postalCode: "CO0 LIO"
            )
        )
    }
}

extension Collection where Element == Venue {

    static func makeMocks() -> [Venue] {
        [
            .makeMock(1),
            .makeMock(2),
            .makeMock(3),
        ]
    }
}

extension VenueGroup {
    static func makeMock() -> VenueGroup {
        Self(name: "Best Coffee Shops", venues: .makeMocks())
    }
}

extension Collection where Element == VenueGroup {
    static func makeMocks() -> [VenueGroup] {
        [
            .makeMock(),
        ]
    }
}
