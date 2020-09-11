//
//  TransportRest.swift
//  LocationManagerTest
//
//  Created by Philipp Hentschel on 06.06.20.
//  Copyright © 2020 Philipp Hentschel. All rights reserved.
//

import Foundation
import Alamofire
import Combine

class TransportRestProvider {
    
    let SERVER = "https://transport.russendis.co"
    
    let decoder = JSONDecoder()
   
    var delegate: TrainDataProviderDelegate? = nil

    var journeys: Set<Journey> = []
    var trips: Array<HafasTrip> = []
    
    
    var stream: AnyCancellable? = nil

    typealias TripData = TimeFrameTrip
    
    init() {
        decoder.dateDecodingStrategy = .formatted(getDateFormatter())
    }
    
    func getAllTrips() -> Array<HafasTrip> {
        return trips
    }
    
    func setDeleate(delegate: TrainDataProviderDelegate) {
        self.delegate = delegate
    }
    
    private func streamOfJourneys(output: [Publishers.Merge<AnyPublisher<Array<HafasJourney>, AFError>,AnyPublisher<Array<HafasJourney>, AFError>>.Output]) -> Set<HafasJourney> {
        return Set(output.flatMap({$0})).filter({ ["nationalExp","nationalExpress", "national", "regionalExp", "regional"].contains($0.line.product) })
    }
    
    private func fetchTripsFromJourneyArray(withJourneys journeys: Set<HafasJourney>) -> AnyPublisher<Array<HafasTrip>, AFError> {
        Log.info("Fetching Trips for \(journeys.count) journeys")
        return Publishers.Sequence(sequence:  self.generateTripPublishers(fromJourneys: journeys)).flatMap { $0 }.collect().eraseToAnyPublisher()
    }
    
    private func generateTripPublishers(fromJourneys journeys: Set<HafasJourney>) -> Array<AnyPublisher<HafasTrip, AFError>> {
        return  Array(journeys).map( { (journey) -> AnyPublisher<HafasTrip, AFError> in
            self.fetchTrip(forJourney: journey)
        })
    }
     
    func update() {
        let station = UserPrefs.getSelectedStation()
        let departures = fetchDepartures(forStation: station.ibnr)
        let arrivals = fetchArrivals(forStation: station.ibnr)
        
        // Cancel old request
        self.stream?.cancel()
        
        let cancellable = Publishers.Merge(departures, arrivals)
            .collect()
            .map(streamOfJourneys)
            .flatMap(fetchTripsFromJourneyArray)
            .receive(on: RunLoop.main).sink(receiveCompletion: { (result) in
                switch result {
                case .failure(let error):
                    Log.error(error)
                case .finished:
                    Log.info(result)
                }
            }) { (trips) in
                self.trips = trips
                self.delegate?.onTripsUpdated()
        }
        
        self.stream = cancellable
    }
    

    // MARK: - Network code
    
    private func fetchDepartures(forStation id: String) -> AnyPublisher<Array<HafasJourney>, AFError> {
        
        /**
        Viewer                         Station
          |____10Minutes_____|
         Now                           10 Minutes earlier
         */
        
        let headers = HTTPHeaders([HTTPHeader(name: "X-Identifier", value: "de.f1ndus.iOS.train")])
        let offset = UserPrefs.getTimeOffset()
        let departureDate = Int(Date().addingTimeInterval(-TimeInterval(offset)).timeIntervalSince1970)
        Log.info("Fetching departures that will pass viewer at \(departureDate) up to \(Date().addingTimeInterval(60*45))")
        //TODO time based on distance/time to station
        let parameters = [
            "when" : String(departureDate),
            "duration" : "45"
        ]
        
        return AF.request("\(self.SERVER)/stations/\(id)/departures", parameters: parameters, headers: headers ).publishDecodable(type: Array<HafasJourney>.self,  decoder: self.decoder).value().receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    private func fetchArrivals(forStation id: String) -> AnyPublisher<Array<HafasJourney>, AFError> {
        
        let headers = HTTPHeaders([HTTPHeader(name: "X-Identifier", value: "de.f1ndus.iOS.train")])
        let offset = UserPrefs.getTimeOffset()
        let arrivalDate = Int(Date().addingTimeInterval(TimeInterval(offset)).timeIntervalSince1970)
        Log.info("Fetching arrivals at \(arrivalDate) to \(Date().addingTimeInterval(60*45))")
        //TODO time based on distance/time to station
        
        let parameters = [
            "when" : String(arrivalDate),
            "duration" : "45"
        ]
        
        return AF.request("\(self.SERVER)/stations/\(id)/arrivals", parameters: parameters, headers: headers ).publishDecodable(type: Array<HafasJourney>.self, decoder: self.decoder).value().receive(on: DispatchQueue.main).eraseToAnyPublisher()
        
    }
    
    private func fetchTrip(forJourney journey: HafasJourney) ->  AnyPublisher<HafasTrip, AFError> {
         
         let headers = HTTPHeaders([HTTPHeader(name: "X-Identifier", value: "de.f1ndus.iOS.train")])
         
         let parameters = [
            "lineName" : journey.line.name,
            "polyline" : "true"
         ]
        
        let urlParameters = URLComponents(string: "\(SERVER)/trips/\(journey.tripId.replacingOccurrences(of: "|", with: "%7C"))")!
        return AF.request(urlParameters.url!, parameters: parameters, headers: headers).publishDecodable(type: HafasTrip.self, decoder: self.decoder).value().receive(on: DispatchQueue.main).eraseToAnyPublisher()
     }
}
