# Coffee Finder

A simple app built using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) that shows coffee shops near your location using the FourSquare API.

## Setup

### Requirements

Xcode 13.1 or later is required to open and build this project.

### Steps

1. Create a FourSquare developer account
2. Create a FourSquare app to obtain Client ID and Client Secret
3. Open the CoffeeFinder.xcodeproj file in Xcode
4. Under the `CoffeeFinder` group, open the `Constants.swift` file
5. Add your Client ID and Client Secret values obtained previously to the appropriate constants
6. Build and run! 🎉 

## Architecture

Uses [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) which is an opinionated library for building apps in a specific way that is loosely based on Redux. At the centre of the application is the "Store", which owns the "State" and receives "Actions" which mutate the "State" using "Reducers".

This approach uses a unidirectional data-flow: Actions -> State -> View -> Actions ....

This is unlike SwiftUI which uses bi-directional data-flow via two-way Bindings. TCA ensures everything is predictable, deterministic and testable. 

## Approach

I wanted to use The Composable Architecture as it's been something that I've been interested in trying more for a while, I really like the single-source-of-truth, the predictable and deterministic nature of state changes, the ease in which it can be tested and that it is completely decoupled from the UI.

If I wasn't to use TCA I would have chosen MVVM for this task.

The other thing worth mentioning is the use of "Static Configurations" a term I coined with a work colleague and it's a pattern I really like. To explain essentially it's an alternative to using protocols for purposes of mocking and stubbing types. 

While Protocols are commonly used for this purpose I feel they are not ideal due to limitations with Swift's implementation of Protocols, most common limitations are around using Protocols as types i.e. in Collections where the Protocol has associated self requirements. 

In my opinion, concrete types are nearly always easier to work with and the "Static Configuration" approach allows us to create live and mock instances from the same concrete type.

You start with your interface which is the real concrete type:

```swift
struct QuoteOfTheDayClient {
    var fetchQuote: ((Result<String, Error>) -> Void) -> Void
}
```

You'll see that the `QuoteOfTheDayClient` type has a single property called `fetchQuote` that accepts a closure with an argument of a callback closure.

We can then create static configuration instances of this type like:

```swift
extension QuoteOfTheDayClient {
    let live = Self(
        fetchQuote: { completion in

            let url = ...

            URLSession.main.dataTaskPublisher(for: url)
                .map { String(data: $0.data, encoding: .utf8) }
                .sink(receiveCompletion: { error in
                    completion(.failure(error))
                }, receiveValue: { quote in
                    completion(.success(quote))
                })
        }
    )
}
```

What's nice is that the entire live implementation is encapsulated within the `live` instance. Now let's create a mock:

```swift
extension QuoteOfTheDayClient {
    let mock = Self(
        fetchQuote: { completion in        
            completion(.success("There are only two hard things in Computer Science: cache invalidation and naming things.
"))
        }
    )
}
```

We can also create failure mocks:

```swift
extension QuoteOfTheDayClient {
    let failure = Self(
        fetchQuote: { completion in
            completion(.failure(Error(...)))
        }
    )
}
```

And to use these static configurations is super simple:

```swift
class SomeClass {
    
    func someFunction() {
        let client: QuoteOfTheDayClient = .live
        ...
    }
}
```

And from tests:

```swift
class SomeTests: XCTestCase {
    
    func testSuccess() {  
        let client: QuoteOfTheDayClient = .mock
        ...
    }

    func testFailure() {  
        let client: QuoteOfTheDayClient = .failure
        ...
    }    
}
```
Apart from static configurations the general approach I took to this task is as follows:

1. Created the project structure and added the required dependencies
2. Created LocationClient and FourSquareClient
3. Created the Views
4. Created the "Actions" and "Reducer" and created an "Environment"
5. Created SwiftUI previews for each state
6. Tested in the simulator and iterated until all in-development issues were resolved 
7. Created the unit tests

I didn't use TDD as this project was fairly exploratory and UI heavy, I wanted to settle on the right solution before expending effort writing tests.  

## Caveats

- To aid review, I've kept the number of files to a minimum and grouped models and clients together and kept the `State`, `Reducers` and `Actions` with the `Views`. In a production app I would separate these in to multiple files. 
- All the mock factory methods return deterministic value types which simplifies testing.
- There is a bug where the mock `LocationClient` effect that is returned as a side-effect of the `.onAppear` action doesn't end running before the affected tests finish which is causing the tests to be failed by TCA. This is because state could continue to be mutated by further events. Unfortunately I ran out of time looking into this, I will continue to investigate and update as soon as I have a fix. It's worth noting the tests technically pass each assertion but the overall test is being failed due to the long running `Effect`.
- I didn't have time to write tests for the `LocationClient` though most of the code is mostly covered by the main CoffeeFinderTests.
- I didn't explicitly handle the case where the user has disabled location services or where location services has already been "always allowed", this could be a future improvement. 
- The assumption here is that the purpose of this task isn't to write fully a finished product but more to see how I would write code, tests, architecture etc and I feel this project fulfils that objective even if I would consider it incomplete. 


## Testing

The test suite is made up of:
- Snapshot UI tests that assert that the UI state is as expected.
- CoffeeFinderTests unit tests that test the state is correctly mutated when performing specific actions.
- FourSquareClientTests unit tests test the custom decodable logic and URLRequest construction.
