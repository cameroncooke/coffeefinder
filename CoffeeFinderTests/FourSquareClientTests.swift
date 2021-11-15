//
//  FourSquareClientTests.swift
//  Copyright © 2021 Cameron Cooke.
//

import XCTest
@testable import CoffeeFinder
import CoreLocation
import CustomDump

class FourSquareClientTests: XCTestCase {

    let scheduler = DispatchQueue.test

    func testDecodeVenueResponse() throws {

        guard let resourceURL = Bundle(for: Self.self).url(forResource: "FourSquareResponse", withExtension: "json") else {
            XCTFail("Unable to load test resource.")
            return
        }

        let data = try Data(contentsOf: resourceURL)
        let venueResponse = try JSONDecoder().decode(VenueResponse.self, from: data)
        XCTAssertNotNil(venueResponse)
    }

    func testClientBuildsExpectedRequest() throws {

        let expectation = self.expectation(description: "Make URL Request")

        let sut = FourSquareClient.live(urlSession: .mock)

        var actualRequestURL: URL?
        MockURLProtocol.requestHandler = { request in
            actualRequestURL = request.url
            expectation.fulfill()
            return nil
        }

        let cancellable = sut.searchVenues(
            CLLocation.makeMock().coordinate.longitude.formatted(),
            CLLocation.makeMock().coordinate.latitude.formatted()
        )
        .eraseToAnyPublisher()
        .receive(on: scheduler)
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        waitForExpectations(timeout: 0.1)

        let actualURL = try XCTUnwrap(actualRequestURL)
        XCTAssertNoDifference(
            actualURL.absoluteString,
            "https://api.foursquare.com/v2/venues/explore?client_id=3011QM3L3UXPCFSLJDYVSCQQ2PISCYHCNUULJ5YVKBSTWDZ0&client_secret=5SM0A1YTI14FGWDQXHJFQ4SFXH1HCYBFSV4DE0RL0YUTYHLZ&section=coffee&v=20211115&ll=50.831806,-0.128818"
        )

        cancellable.cancel()
    }
}
