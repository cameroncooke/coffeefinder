//
//  CoffeeFinderApp.swift
//  Copyright © 2021 Cameron Cooke.
//

import SwiftUI
import ComposableArchitecture

@main
struct CoffeeFinderApp: App {

    init() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear

        if ProcessInfo.processInfo.environment[Constants.Test.animationsEnabledKey] == "NO" {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            CoffeeFinderView(
                store: Store(
                    initialState: CoffeeFinderState(),
                    reducer: coffeeFinderReducer,
                    environment: CoffeeFinderEnvironment(
                        fourSquareClient: .live(),
                        locationClient: .live,
                        mainQueue: .main
                    )
                )
            )
        }
    }
}
