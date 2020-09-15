//
//  TripHandler.swift
//  Trainspot.App
//
//  Created by Philipp Hentschel on 15.09.20.
//  Copyright © 2020 Philipp Hentschel. All rights reserved.
//

import Foundation
import TripVisualizer
import CoreLocation

//TODO proxy holder for controller
public class TripHandler {
    
    private let manager = TrainLocationProxy.shared
    public static let shared = TripHandler()
    private var tripTimeFrameLocationController = TrainLocationTripByTimeFrameController()
    
    private init() {
        #if MOCK
        self.setupDemo()
        #else
        tripTimeFrameLocationController.setDataProvider(withProvider: TripProvider(NetworkTrainDataTimeFrameProvider()))
        #endif
        
        self.manager.register(controller: tripTimeFrameLocationController)
    }
    
    func setupDemo() {
        var components = DateComponents()
        components.second = 0
        components.hour = 23
        components.minute = 30
        components.day = 13
        components.month = 9
        components.year = 2020
        let date = Calendar.current.date(from: components)
        let traveler = TimeTraveler()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            traveler.travel(by: 1)
        }
        traveler.date = date!
        self.tripTimeFrameLocationController.pause()

        tripTimeFrameLocationController.setDataProvider(withProvider: TripProvider(MockTrainDataTimeFrameProvider(withFile: "bs_delay")))
        tripTimeFrameLocationController.dateGenerator = traveler.generateDate
        
        let loc = CLLocation(latitude: 52.2310468, longitude: 10.4268998)
        tripTimeFrameLocationController.setCurrentLocation(location: loc)
        UserLocationController.shared.deactivate()
        UserPrefs.setManualLocationEnabled(true)
        UserPrefs.setManualLocation(loc)
        UserPrefs.setSelectedStation(StationInfo("Braunschweig Hbf", "8000049"))
    }
    
    func start() {
        self.triggerUpdate()
    }
    
    func stop() {
        self.tripTimeFrameLocationController.pause()
    }
    
    func forceStart() {
        self.tripTimeFrameLocationController.fetchServer()
    }
    
    func triggerUpdate() {
        if UserPrefs.getfirstOnboardingTriggered() == true {
            self.tripTimeFrameLocationController.fetchServer()
        }
    }
    
    func setCurrentLocation(_ location: CLLocation) {
        self.tripTimeFrameLocationController.setCurrentLocation(location: location)
    }
        
}