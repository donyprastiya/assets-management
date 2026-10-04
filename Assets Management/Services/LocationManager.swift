//
//  LocationManager.swift
//  Assets Management
//
//  Created by Dony on 05/08/25.
//

import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var locationString: String = "Mencari lokasi..."
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let placemark = placemarks?.first {
                self.locationString = "\(placemark.locality ?? ""), \(placemark.country ?? "")"
            }
        }
        manager.stopUpdatingLocation() // Hemat baterai
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Gagal mendapatkan lokasi: \(error.localizedDescription)")
        self.locationString = "Lokasi tidak tersedia"
    }
}
