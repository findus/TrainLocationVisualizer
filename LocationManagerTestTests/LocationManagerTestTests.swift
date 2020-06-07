//
//  LocationManagerTestTests.swift
//  LocationManagerTestTests
//
//  Created by Philipp Hentschel on 06.06.20.
//  Copyright © 2020 Philipp Hentschel. All rights reserved.
//

import XCTest

@testable import LocationManagerTest

class LocationManagerTestTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testDownloads() {
        let t = TransportRestProvider()
        t.update()
        let exp = XCTestExpectation()
        let await = wait(for: [exp], timeout: 10)
    }

}