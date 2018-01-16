//
//  SiteRatingScoreExtensionTests.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


import XCTest
@testable import Core

class SiteRatingGradeTests: XCTestCase {

    struct Url {
        static let http = URL(string: "http://example.com")!
        static let https = URL(string: "https://example.com")!
        static let googleNetwork = URL(string: "https://google.com")!
        
        static let duckduckgo = URL(string: "http://duckduckgo.com")!
    }
    
    struct MockTrackerBuilder {

        static func standard(category: String = "", blocked: Bool) -> DetectedTracker {
            return DetectedTracker(url: "trackerexample.com", networkName: "someSmallAdNetwork.com", category: category, blocked: blocked)
        }

        static func ipTracker(category: String = "", blocked: Bool) -> DetectedTracker {
            return DetectedTracker(url: "http://192.168.5.10/abcd", networkName: "someSmallAdNetwork.com", category: category, blocked: blocked)
        }

        static func google(category: String = "", blocked: Bool) -> DetectedTracker {
            return DetectedTracker(url: "trackerexample.com", networkName: "Google", category: category, blocked: blocked)
        }

    }

    fileprivate let classATOS = MockTermsOfServiceStore().add(domain: "example.com", classification: .a, score: -100)
    fileprivate let disconnectMeTrackers = ["googletracker.com": DisconnectMeTracker(url: Url.googleNetwork.absoluteString, networkName: "Google")]

    override func setUp() {
        SiteRatingCache.shared.reset()
    }
    
    func testWhenNetworkExistsForMajorDomainNotInDisconnectItIsReturned() {
        let disconnectMeTrackers = ["sometracker.com": DisconnectMeTracker(url: Url.http.absoluteString, networkName: "TrickyAds", category: .social ) ]
        let networkStore = MockMajorTrackerNetworkStore().adding(network: MajorTrackerNetwork(name: "Major", domain: "major.com", perentageOfPages: 5))
        let testee = SiteRating(url: Url.googleNetwork, disconnectMeTrackers: disconnectMeTrackers, termsOfServiceStore: classATOS, majorTrackerNetworkStore: networkStore)
        let nameAndCategory = testee.networkNameAndCategory(forDomain: "major.com")
        XCTAssertEqual("Major", nameAndCategory.networkName)
        XCTAssertNil(nameAndCategory.category)
    }

    func testWhenNetworkNameAndCategoryExistsForUppercasedDomainTheyAreReturned() {
        let disconnectMeTrackers = ["sometracker.com": DisconnectMeTracker(url: Url.http.absoluteString, networkName: "TrickyAds", category: .social ) ]
        let testee = SiteRating(url: Url.googleNetwork, disconnectMeTrackers: disconnectMeTrackers, termsOfServiceStore: classATOS)
        let nameAndCategory = testee.networkNameAndCategory(forDomain: "SOMETRACKER.com")
        XCTAssertEqual("TrickyAds", nameAndCategory.networkName)
        XCTAssertEqual("Social", nameAndCategory.category)
    }

    func testWhenNetworkNameAndCategoryExistsForDomainTheyAreReturned() {
        let disconnectMeTrackers = ["sometracker.com": DisconnectMeTracker(url: Url.http.absoluteString, networkName: "TrickyAds", category: .social ) ]
        let testee = SiteRating(url: Url.googleNetwork, disconnectMeTrackers: disconnectMeTrackers, termsOfServiceStore: classATOS)
        let nameAndCategory = testee.networkNameAndCategory(forDomain: "sometracker.com")
        XCTAssertEqual("TrickyAds", nameAndCategory.networkName)
        XCTAssertEqual("Social", nameAndCategory.category)
    }
    
    func testWhenHighScoreCachedThenBeforeGradeIsD() {
        let entry = SiteRatingCache.CacheEntry(score: 10, uniqueTrackerNetworksDetected: 0, uniqueTrackerNetworksBlocked: 0, uniqueMajorTrackerNetworksDetected: 0, uniqueMajorTrackerNetworksBlocked: 0, hasOnlySecureContent: true)
        
        _ = SiteRatingCache.shared.add(url: Url.https, entry: entry)
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore())
        let before = testee.beforeGrade
        XCTAssertEqual(SiteGrade.d, before)
    }

    func testWhenHTTPSAndClassATOSWithTrackersThenBeforeGradeIsCAndAfterGradeIsA() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .a, score: 0))

        for _ in 0 ..< 11 {
            testee.trackerDetected(MockTrackerBuilder.standard(blocked: false))
        }

        XCTAssertEqual(.c, testee.beforeGrade)
        XCTAssertEqual(.a, testee.afterGrade)
    }

    func testWhenSingleTrackerDetectedAndHTTPSAndClassATOSThenBeforeGradeIsBAndAfterGradeIsA() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .a, score: 0))
        testee.trackerDetected(MockTrackerBuilder.standard(blocked: false))
        XCTAssertEqual(.b, testee.beforeGrade)
        XCTAssertEqual(.a, testee.afterGrade)
    }

    func testWhenObsecureTrackerDetectedAndHTTPSAndClassATOSThenBeforeGradeIsCAndAfterGradeIsA() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .a, score: 0))
        testee.trackerDetected(MockTrackerBuilder.ipTracker(blocked: true))
        XCTAssertEqual(.c, testee.beforeGrade)
        XCTAssertEqual(.a, testee.afterGrade)
    }

    func testWhenNoTrackersHTTPSAndClassATOSThenLoadsInsecureResourceThenGradeIsB() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .a, score: 0))
        testee.hasOnlySecureContent = false
        XCTAssertEqual(.b, testee.beforeGrade)
        XCTAssertEqual(.b, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPAndClassATOSThenGradeIsB() {
        let testee = SiteRating(url: Url.http, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .a, score: 0))
        XCTAssertEqual(.b, testee.beforeGrade)
        XCTAssertEqual(.b, testee.afterGrade)
    }

    func testWhenTrackerDetectedInMajorTrackerNetworkAndHTTPSAndClassATOSThenBeforeGradeIsCAndAfterGradeIsB() {
        let disconnectMeTrackers = [Url.https.host!: DisconnectMeTracker(url: Url.googleNetwork.absoluteString, networkName: "Google")]
        let networkStore = MockMajorTrackerNetworkStore().adding(network: MajorTrackerNetwork(name: "Google", domain: Url.googleNetwork.host!, perentageOfPages: 84))
        let testee = SiteRating(url: URL(string: "https://another.com")!, disconnectMeTrackers: disconnectMeTrackers, termsOfServiceStore: classATOS, majorTrackerNetworkStore: networkStore)
        testee.trackerDetected(DetectedTracker(url: "https://tracky.com/tracker.js", networkName: nil, category: nil, blocked: false))
        XCTAssertEqual(.c, testee.beforeGrade)
        XCTAssertEqual(.b, testee.afterGrade)
    }

    func testWhenSiteIsMajorTrackerNetworkAndHTTPSAndClassAThenDGrade() {
        let networkStore = MockMajorTrackerNetworkStore().adding(network: MajorTrackerNetwork(name: "Google", domain: Url.googleNetwork.host!, perentageOfPages: 84))
        let testee = SiteRating(url: Url.googleNetwork, disconnectMeTrackers: disconnectMeTrackers, termsOfServiceStore: classATOS, majorTrackerNetworkStore: networkStore)
        XCTAssertEqual(.d, testee.beforeGrade)
        XCTAssertEqual(.d, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndPositiveTOSThenCGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: nil, score: 10))
        XCTAssertEqual(.c, testee.beforeGrade)
        XCTAssertEqual(.c, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndNegativeTOSThenAGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: nil, score: -10))
        XCTAssertEqual(.a, testee.beforeGrade)
        XCTAssertEqual(.a, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndClassETOSThenDGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .e, score: 0))
        XCTAssertEqual(.d, testee.beforeGrade)
        XCTAssertEqual(.d, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndClassDTOSThenCGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .d, score: 0))
        XCTAssertEqual(.c, testee.beforeGrade)
        XCTAssertEqual(.c, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndClassCTOSThenBGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .c, score: 0))
        XCTAssertEqual(.b, testee.beforeGrade)
        XCTAssertEqual(.b, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndClassBTOSThenBGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .b, score: 0))
        XCTAssertEqual(.b, testee.beforeGrade)
        XCTAssertEqual(.b, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndClassATOSThenAGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore().add(domain: Url.https.host!, classification: .a, score: 0))
        XCTAssertEqual(.a, testee.beforeGrade)
        XCTAssertEqual(.a, testee.afterGrade)
    }

    func testWhenNoTrackersAndHTTPSAndNoTOSThenBGrade() {
        let testee = SiteRating(url: Url.https, termsOfServiceStore: MockTermsOfServiceStore())
        XCTAssertEqual(SiteGrade.b, testee.beforeGrade)
        XCTAssertEqual(SiteGrade.b, testee.afterGrade)
    }

}

fileprivate class MockTermsOfServiceStore: TermsOfServiceStore {

    var terms = [String : TermsOfService]()

    func add(domain: String, classification: TermsOfService.Classification?, score: Int, goodReasons: [String] = [], badReasons: [String] = []) -> MockTermsOfServiceStore {
        terms[domain] = TermsOfService(classification: classification, score: score, goodReasons: goodReasons, badReasons: badReasons)
        return self
    }

}

fileprivate class MockMajorTrackerNetworkStore: InMemoryMajorNetworkStore {

    override init(networks: [MajorTrackerNetwork] = []) {
        super.init(networks: networks)
    }

    func adding(network: MajorTrackerNetwork) -> MajorTrackerNetworkStore {
        var networks = self.networks
        networks.append(network)
        return MockMajorTrackerNetworkStore(networks: networks)
    }

}
