//
//  MapViewController.swift
//  LocationManagerTest
//
//  Created by Philipp Hentschel on 03.06.20.
//  Copyright © 2020 Philipp Hentschel. All rights reserved.
//

import UIKit
import MapKit
import TripVisualizer
import SwiftEventBus

enum LineType {
    case normal
    case selected
    
    public func get() -> String {
        switch self {
        case .normal:
            return "normal"
        case .selected:
            return "selected"
        }
    }
}

class MapViewController: UIViewController {

    
    @IBOutlet weak var map: MKMapView!

    private var entryList: Array<MapEntity> = Array()
    private var markerDict: Dictionary<String, MKPointAnnotation> = Dictionary.init()
    private var lineDict: Dictionary<String, TrainTrackPolyLine> = Dictionary.init()
    
    private var fakedUserPosition: MKPointAnnotation?
    private var nearestTrackPolyline: MKPolyline?
    private var firstLaunch = true
    
    weak var delegate: MapViewControllerDelegate?
    
    override func viewDidLoad() {
        
        self.map.showsUserLocation = true
        
        let lpgr = UILongPressGestureRecognizer(target: self, action:  #selector(longpress(sender:)))
        lpgr.minimumPressDuration = 0.5
        map.addGestureRecognizer(lpgr)
        
        map.delegate = self;
        
        self.setupEventBusListener()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Check if locationmanager is still active
        self.map.showsUserLocation = !UserPrefs.isManualLocationEnabled()
       
        if UserPrefs.isManualLocationEnabled() {
            self.addFakedUserPosition(onLocation: UserPrefs.getManualLocation().coordinate)
        }
        
        self.updateUserPosAnnotationOpacity()
    }
    
    public func setBottomContentAnchor(_ height: CGFloat) {
        self.map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: height, right: 0)
    }
    
    public func centerCamera(atTripWithId id: String) {
        let coords = self.markerDict[id]!
                
        if UserPrefs.isManualLocationEnabled() {
            self.addFakedUserPosition(onLocation: UserPrefs.getManualLocation().coordinate)
            self.map.showAnnotations([coords, self.fakedUserPosition!], animated: true)
        } else {
            self.map.showAnnotations([coords, self.map.userLocation], animated: true)
        }

    }
    
    private func addFakedUserPosition(onLocation location: CLLocationCoordinate2D) {
        
        if let annotation = self.fakedUserPosition {
            self.map.removeAnnotation(annotation)
        }
        
        let pin = MKPointAnnotation()
        pin.coordinate = location
        pin.accessibilityLabel = "manualSetPin"
        self.map.addAnnotation(pin)
        self.fakedUserPosition = pin
    }
    
    private func selectTrip(withId id: String) {
        let annotation = self.markerDict[id]
        self.map.selectAnnotation(annotation!, animated: true)
        self.highlightPresentLine(forTripId: id)
        
        //Reduces opacity of any other visible, non selected map annotation
        for annotation in self.map.annotations {
            let anView = self.map.view(for: annotation) as? MKTrainAnnotationView
            if let view = anView {
                if (annotation as? TrainAnnotation)?.tripId != id {
                    view.animatedAlpha(toValue: 0.2)
                } else {
                    view.animatedAlpha(toValue: 1.0)
                }
            }
        }
        
    }
    
    private func drawNewLine(forTrip trip: Trip) {
        let coords = trip.polyline.map { $0.location.coordinate }
        let polyline = TrainTrackPolyLine(coordinates: coords, count: coords.count)
        self.map.insertOverlay(polyline, at: 0)
        self.lineDict[trip.tripId] = polyline
    }
    
    private func highlightPresentLine(forTripId id: String) {
        
        deHighlightLines()
        
        guard let line = self.lineDict[id] else {
            Log.warning("Could not find polyline from trip that should get highlighted")
            return
        }
        
        line.type = .selected
        
        if let renderer = self.map.renderer(for: line) as? MKPolylineRenderer {
            renderer.strokeColor = .red
            renderer.lineWidth = 1.2
            renderer.invalidatePath()
        }
        
        //add line to front
        self.map.removeOverlay(line)
        self.map.addOverlay(line)

        
    }
    
    private func getHighlightedLines() -> [TrainTrackPolyLine] {
        return self.lineDict.values.filter({ (polyline) -> Bool in
            polyline.type?.get() == "selected"
        })
    }
    
    private func updateUserPosAnnotationOpacity() {
        
        guard let pin = map.annotations.filter({ (annotation) -> Bool in
            (annotation as? MKPointAnnotation)?.accessibilityLabel == "manualSetPin"
        }).first else {
            return
        }
        
        self.map.view(for: pin)?.alpha = UserPrefs.isManualLocationEnabled() ? 1.0 : 0.4
    }
    
    private func deHighlightLines() {
        
        getHighlightedLines().forEach { (line) in
            line.type = .normal
            if let renderer = self.map.renderer(for: line) as? MKPolylineRenderer {
                renderer.strokeColor = .white
                renderer.lineWidth = 1.0
                renderer.invalidatePath()
            }
        }
        
    }
    
    /**
     Draws a polyline of the passed trip. Based on the type the line will be rendered differently
     Only one selected line can exists, if another one gets passed to the controller the old one gets redrawn with a normal style
     */
    func drawLine(forTrip trip: Trip, withLineType type: LineType) {
        
        //Check if line is already there
        let tripLine = self.lineDict[trip.tripId]
        
        if tripLine != nil && type.get() == "selected" {
            self.highlightPresentLine(forTripId: trip.tripId)
        } else if tripLine == nil {
            self.drawNewLine(forTrip: trip)
        } else {
            Log.warning("\(trip.tripId)|\(trip.name) already has polyline on mapview, skipping")
        }

    }
    
    func setLineToNearestTrack(forTrackPosition position: CLLocationCoordinate2D,
                               andUserlocation userLocation: CLLocationCoordinate2D) {
        
        //Remove old one if present
        if let polyline = self.nearestTrackPolyline {
            self.map.removeOverlay(polyline)
        }
        
        let polyline = MKPolyline(coordinates: [userLocation, position], count: 2)
        self.nearestTrackPolyline = polyline
        self.map.addOverlay(polyline)
    }
    
    func removeAllEntries() {
        self.map.removeAnnotations(self.map.annotations)
        self.map.removeOverlays(self.map.overlays)
        self.markerDict = Dictionary.init()
        self.lineDict = Dictionary.init()
        self.entryList = Array.init()
    }
    
    @objc func longpress(sender: UIGestureRecognizer) {
        guard sender.state == .began else { return }
        let location = sender.location(in: self.map)
        let coord = self.map.convert(location, toCoordinateFrom: self.map)
        self.addFakedUserPosition(onLocation: coord)
        self.delegate?.userPressedAt(location: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
    }
    
}

// MARK: - MapViewControllerProtocol

extension MapViewController: MapViewControllerProtocol {
    
    /**
     Deletes a train that is currently added to the map-view
     name:  The detailed trip id that was passed als url parameter to hafas
     label: The line name of the trip for example RE70
     */
    func deleteEntry(withName: String, andLabel: String) {
        
        Log.debug("Remove \(withName)|\(andLabel) from map")
        
        if let annotation = self.markerDict[withName]  {
            
            self.map.removeAnnotation(annotation)
            
        } else {
            Log.warning(" \(andLabel) Could not remove Annotation")
        }
        
        
        if let line = self.lineDict[withName]  {
            
            self.map.removeOverlay(line)
            
        } else {
            Log.warning(" \(andLabel) Could not remove Line")
        }
        
        self.entryList.removeAll { (entity) -> Bool in
            entity.tripId == withName
        }
        
        self.lineDict.removeValue(forKey: withName)
        
        self.markerDict.removeValue(forKey: withName)
        
    }
    
    func addEntry(entry: MapEntity) {
        
        Log.debug("Add \(entry.name)|\(entry.tripId) from map")
        
        entryList.append(entry)
        let pin = TrainAnnotation()
        pin.coordinate = entry.location.coordinate
        pin.title = entry.name
        pin.tripId = entry.tripId
        markerDict[entry.tripId] = pin
        self.map.addAnnotation(pin)
    }
    
    func updateTrainLocation(forId id: String, withLabel label: String, toLocation location: CLLocationCoordinate2D, withDuration duration: Double) {
        
        //Zoom to boundaries on first launch
        if self.firstLaunch == true {
            self.firstLaunch = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let fakedUserPosition = self.fakedUserPosition {
                    self.map.showAnnotations( Array(self.markerDict.values) + [fakedUserPosition] , animated: true)
                } else {
                    self.map.showAnnotations( Array(self.markerDict.values) + [self.map.userLocation] , animated: true)
                }
            }
        }
        
        guard let entry = self.entryList.filter({ $0.tripId == id }).first else {
            Log.warning("No MapEntry found for \(id), will create entry at location")
            self.addEntry(entry:
                MapEntity(name: label, tripId: id, location: CLLocation(latitude: location.latitude, longitude: location.longitude))
            )
            
            return
        }
        
        let pin = self.markerDict[entry.tripId]
        let endPoint = location
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveLinear, animations: {
            // Update annotation coordinate to be the destination coordinate
            pin!.coordinate = endPoint
        }, completion: nil)
        
    }
        
}

//MARK: - MKMapviewDelegate

extension MapViewController: MKMapViewDelegate
{
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        if overlay is TrainTrackPolyLine {
            let line = overlay as! TrainTrackPolyLine
            let polylineRenderer = MKPolylineRenderer(overlay: line)
            if line.type == .some(.selected) {
                polylineRenderer.strokeColor = #colorLiteral(red: 0.9215893149, green: 0.2225639522, blue: 0.2431446314, alpha: 0.8295162671)
                polylineRenderer.lineWidth = 2
            } else {
                polylineRenderer.strokeColor = #colorLiteral(red: 0.7667021683, green: 0.7898159898, blue: 0.7819377446, alpha: 1)
                polylineRenderer.lineWidth = 1
            }
            return polylineRenderer
        }
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .gray
        renderer.lineWidth = 1
        renderer.lineDashPattern = [2, 5];
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    {
        
        var annotationView: MKTrainAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView") as? MKTrainAnnotationView
        
        if annotationView == nil {
            annotationView = MKTrainAnnotationView.loadViewFromNib()
        }
        
        guard let an = (annotation as? TrainAnnotation) else {
            
            if annotation is MKUserLocation {
                return nil
            }
            // User defined position Annotation
            if annotation is MKPointAnnotation {
                let basicAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "manual")
                basicAnnotationView.alpha = UserPrefs.isManualLocationEnabled() ? 1.0 : 0.4
                return basicAnnotationView
            }
            
            return nil
        }
        
        guard let view = annotationView else {
            return nil
        }
        
        if self.getHighlightedLines().count > 0 {
            view.alpha = 0.2
        }
        
        view.positionDot.layer.cornerRadius = 2
        view.centerOffset = CGPoint(x: 0, y: (-(view.frame.height) / 2) + 2)
        view.canShowCallout = true
        view.rightCalloutAccessoryView = UIButton.init(type: .detailDisclosure)
        
        view.icon.isHidden = false
        view.label.isHidden = true
        view.label.layer.masksToBounds = true

        switch an.title! {
        case let str where str.lowercased().contains("eno"):
            view.icon.image = #imageLiteral(resourceName: "enno")
        case let str where str.lowercased().contains("erx"):
            view.icon.image = #imageLiteral(resourceName: "erixx")
        case let str where str.lowercased().contains("wfb"):
            view.icon.image = #imageLiteral(resourceName: "westfalenbahn")
        case let str where str.lowercased().contains("ice"):
            view.icon.image = #imageLiteral(resourceName: "ice")
        case let str where str.lowercased().contains("ic "):
            view.icon.image = #imageLiteral(resourceName: "ic")
        case let str where str.lowercased().contains("rb") || str.lowercased().contains("re"):
            view.icon.isHidden = true
            view.label.isHidden = false
            view.label.text = an.title
        default:
            view.icon.isHidden = true
            view.label.isHidden = false
            view.label.text = an.title
        }

        return view
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else
        {
            return
        }
        
        guard let tripId = (annotation as? TrainAnnotation)?.tripId else {
            return
        }
        
        // TODO pass tripId to Annotation
        guard let entry = self.entryList.filter({ $0.tripId == tripId }).first else {
            return
        }
        
        SwiftEventBus.post("selectTripOnMap",sender: entry.tripId)
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
       
        SwiftEventBus.post("deSelectTripOnMap")
        
        self.deHighlightLines()
        
        self.resetOpacity()
    }

}

//MARK: -- Event Bus Handling

extension MapViewController {
    private func setupEventBusListener() {
        SwiftEventBus.onMainThread(self, name: "selectTripOnMap") { notification in
            if let tripID = notification?.object as? String {
                self.centerCamera(atTripWithId: tripID)
                self.selectTrip(withId: tripID)
            } else if let trip = notification?.object as? Trip {
                self.centerCamera(atTripWithId: trip.tripId)
                self.selectTrip(withId: trip.tripId)
            }
        }

    }
    
    private func resetOpacity() {
        for annotation in self.map.annotations {
            let anView = self.map.view(for: annotation) as? MKTrainAnnotationView
            if let view = anView {
                view.animatedAlpha(toValue: 1.0)
            }
        }
    }
    
    
}
