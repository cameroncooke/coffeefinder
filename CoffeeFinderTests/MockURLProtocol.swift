//
//  MockURLProtocol.swift
//  Copyright © 2021 Cameron Cooke.
//

import Foundation

// Mock URLProtocol so that we can intercept requests by implementing
// our own URLSession logic. Uses a static requestHandler because URLSession
// instantiates the class directly so the only way for outside-world to set
// the handler is to define it as a static class bound variable. This means that
// only one instance of MockURLProtocol should be used per test to avoid unexpected callbacks.
class MockURLProtocol: URLProtocol {

    typealias RequestHandler = (URLRequest) -> (HTTPURLResponse, Data)?
    static var requestHandler: RequestHandler?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {

        guard let requestHandler = Self.requestHandler else {
            fatalError("requestHandler must be set before using this mock")
        }

        let (response, data) = requestHandler(request) ?? (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!,

            // According to objc.io it's safe to force unwrap as UTF8. Swift
            // uses unicode internally, optionality only exists for where
            // other encodings may not be decodable from the given string.
            // See: https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
            "{}".data(using: .utf8)!
        )

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // no-op
    }
}

extension URLSession {
    static var mock: URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
