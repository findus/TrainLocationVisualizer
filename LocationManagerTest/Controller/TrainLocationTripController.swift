//
//  TrainLocationTripController.swift
//  LocationManagerTest
//
//  Created by Philipp Hentschel on 04.06.20.
//  Copyright © 2020 Philipp Hentschel. All rights reserved.
//

import Foundation

class TrainLocationTripController: TrainLocationProtocol  {
    
    weak var delegate: TrainLocationDelegate?
        
    var trips: Array<Trip> = [Trip]()
    var timer: Timer? = nil
            
    init() {
        self.timer = Timer.scheduledTimer(timeInterval: DURATION, target: self, selector: #selector(eventLoop), userInfo: nil, repeats: true)
    }
    
    func register(trip: Trip) {
        self.trips.append(trip)
        self.delegate?.trainPositionUpdated(forTrip: trip, toPosition: 0, withDuration: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.updateTrip(trip: trip)
        }
    }
    
    @objc private func eventLoop() {
        print("Event loop")
        self.trips.forEach { (trip) in
            self.updateTrip(trip: trip)
        }
    }
    
    private func updateTrip(trip: Trip) {
        guard let arrayPosition = trip.currentTrainPosition(forTrip: trip) else {
            return
        }
        self.delegate?.trainPositionUpdated(forTrip: trip, toPosition: arrayPosition, withDuration: DURATION)
    }
}
